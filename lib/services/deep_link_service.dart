// lib/services/deep_link_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';

import '../models/notification.dart';
import '../providers/subscription_provider.dart';
import '../router/app_router.dart';
import 'notification_service.dart';
import 'nochpay_service.dart';

/// Gère les deep links de retour paiement NotchPay :
///   `yourapp://payment?reference=<reference>`
///
/// Quand le client a terminé le paiement sur la page sécurisée NotchPay (ou
/// le checkout du SDK), NotchPay peut rediriger vers ce schéma custom pour
/// revenir automatiquement dans l'app. Ce service :
///   1. relit la référence de transaction,
///   2. vérifie le paiement via notre serveur de callback (source de vérité)
///      puis, en repli, directement auprès de l'API NotchPay,
///   3. supprime la transaction en attente et rafraîchit l'abonnement,
///   4. notifie l'utilisateur et ramène l'app sur le tableau de bord.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  /// Schéma custom enregistré dans Info.plist (iOS) et AndroidManifest (Android).
  static const String scheme = 'yourapp';
  static const String host = 'payment';

  StreamSubscription<String?>? _sub;
  bool _started = false;

  /// Démarre l'écoute des deep links (idempotent — à appeler une seule fois).
  void start() {
    if (_started) return;
    _started = true;
    _listen();
  }

  Future<void> _listen() async {
    // Lien initial (app démarrée via un deep link — cold start).
    try {
      final initial = await getInitialLink();
      if (initial != null && initial.isNotEmpty) {
        _handle(initial);
      }
    } catch (e) {
      debugPrint('⚠️ DeepLink (initial): $e');
    }

    // Liens reçus pendant que l'app tourne.
    try {
      _sub = linkStream.listen((String? link) {
        if (link != null && link.isNotEmpty) _handle(link);
      }, onError: (Object e) {
        debugPrint('⚠️ DeepLink (stream): $e');
      });
    } catch (e) {
      debugPrint('⚠️ DeepLink (listen): $e');
    }
  }

  /// [TEST] Simule la réception d'un deep link de retour de paiement
  /// (`yourapp://payment?reference=<reference>`) pour vérifier le flux complet
  /// depuis l'écran de paiement.
  ///
  /// - [forceSuccess] = false : vérifie réellement le paiement (serveur puis
  ///   API NotchPay en repli) — utile quand des clés valides sont configurées.
  /// - [forceSuccess] = true  : court-circuite la vérification et déclenche
  ///   directement l'activation (rafraîchit l'abonnement, navigue, notifie)
  ///   pour valider visuellement le retour sans paiement réel.
  Future<void> handleTestLink(
    String reference, {
    bool forceSuccess = false,
  }) async {
    final link = '$scheme://$host?reference=$reference';
    debugPrint('🧪 DeepLink (test): $link');
    if (forceSuccess) {
      await _completeSuccess(reference);
    } else {
      await _handle(link);
    }
  }

  Future<void> _handle(String link) async {
    debugPrint('🔗 Deep link reçu: $link');
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (uri.scheme != scheme || uri.host != host) return;

    final reference = uri.queryParameters['reference'] ?? '';
    if (reference.isEmpty) return;

    await _verifyAndComplete(reference);
  }

  Future<void> _verifyAndComplete(String reference) async {
    final nochPay = NochPayService();

    // 1) Vérifier le statut réel du paiement (serveur → repli API NotchPay).
    bool success = false;
    try {
      final verified = await nochPay.verifyPaymentViaServer(reference);
      success = verified['success'] == true && verified['is_success'] == true;
      if (!success) {
        // Repli direct sur l'API NotchPay (statut `complete`/`paid`).
        final fallback = await nochPay.checkPaymentStatus(reference);
        success =
            fallback['success'] == true && fallback['is_success'] == true;
      }
    } catch (e) {
      debugPrint('⚠️ DeepLink (verify): $e');
    }

    if (!success) {
      _notify(
        title: '⚠️ Paiement non confirmé',
        body: "Le paiement $reference n'a pas pu être confirmé. "
            'Contactez le support si le débit a eu lieu.',
      );
      return;
    }

    await _completeSuccess(reference);
  }

  /// Termine le flux de retour : nettoie la transaction en attente,
  /// rafraîchit l'abonnement, navigue vers le tableau de bord et notifie.
  Future<void> _completeSuccess(String reference) async {
    final nochPay = NochPayService();

    // Nettoyer la transaction en attente correspondante.
    try {
      final pending = await nochPay.getAllPendingTransactions();
      for (final p in pending) {
        if (p['transaction_id'] == reference || p['reference'] == reference) {
          await nochPay.removePendingTransaction(
            p['transaction_id']?.toString() ?? reference,
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('⚠️ DeepLink (cleanup): $e');
    }

    // Rafraîchir l'abonnement et afficher le message de succès.
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final sub = Provider.of<SubscriptionProvider>(ctx, listen: false);
        await sub.refresh();
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          const SnackBar(
            content: Text('🎉 Paiement confirmé — abonnement activé !'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('⚠️ DeepLink (refresh): $e');
      }
      try {
        GoRouter.of(ctx).go('/dashboard');
      } catch (e) {
        debugPrint('⚠️ DeepLink (nav): $e');
      }
    }

    _notify(
      title: '🎉 Paiement confirmé',
      body: 'Votre abonnement a été activé avec succès.',
    );
  }

  void _notify({required String title, required String body}) {
    try {
      NotificationService().addNotification(
        AppNotification(
          title: title,
          body: body,
          type: NotificationType.system_update.toString(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ DeepLink (notif): $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
