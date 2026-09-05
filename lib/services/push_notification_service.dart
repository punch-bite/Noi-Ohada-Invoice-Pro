// lib/services/push_notification_service.dart
//
// 🔔 Notifications PUSH (Firebase Cloud Messaging) — invites d'équipe,
// paiements d'abonnement et autres alertes serveur.
//
// Architecture :
//   • Le serveur (server/index.js) écrit une notification Firestore PUIS
//     envoie une push FCM à tous les appareils du destinataire
//     (collection `fcm_tokens`).
//   • App au premier plan  → `onMessage` → bannière locale
//     (flutter_local_notifications) — FCM n'affiche rien en foreground.
//   • App en arrière-plan / kill → le payload `notification` est affiché
//     par le système automatiquement (aucun code nécessaire).
//   • Tap sur la notification → navigation contextuelle (go_router).
//   • Le token FCM est lié à l'UID Firebase (`fcm_tokens/{token}`) :
//     enregistré au login, purgé au logout, rafraîchi automatiquement.
//
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_router.dart';

/// 📢 Canal Android des notifications push (doit matcher le meta-data du
/// manifeste ET le `channelId` envoyé par le serveur).
const String kPushChannelId = 'noi_notifications';
const String kPushChannelName = 'Notifications NOI OHADA Invoice Pro';

/// Handler TOP-LEVEL obligatoire pour les messages reçus en arrière-plan
/// (exécuté dans un isolate séparé — aucune manipulation d'UI ici).
/// Les messages portant un payload `notification` sont de toute façon
/// affichés par le système ; ce hook sert de trace + data-only futur.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Push arrière-plan: ${message.messageId} / ${message.data}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  String? _lastNavigatedMessageId; // dédoublonne tap initial / openedApp
  bool _initialized = false;
  String? _registeredUid;

  /// Push supporté : Android & iOS uniquement (web = VAPID à configurer,
  /// desktop = non supporté par firebase_messaging).
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialise permissions, affichage local, handlers FCM et l'écoute
  /// de l'état d'authentification (enregistrement/purge des tokens).
  /// Idempotent et non-bloquant : chaque étape est protégée.
  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    try {
      // ---- Permissions (Android 13+ / iOS) ----
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // ---- Affichage local (bannière en avant-plan) ----
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        // FCM `requestPermission` gère déjà la permission iOS.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
          const AndroidNotificationChannel(
        kPushChannelId,
        kPushChannelName,
        description: 'Invitations d\'équipe, paiements et alertes',
        importance: Importance.high,
      ));

      // ---- Messages FCM ----
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _onMessageSub = FirebaseMessaging.onMessage
          .listen(_showForegroundNotification);
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
        _lastNavigatedMessageId = m.messageId;
        _navigateFromMessage(m.data);
      });
      // App démarrée depuis un tap sur une notification (terminated).
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null && initial.messageId != _lastNavigatedMessageId) {
        _lastNavigatedMessageId = initial.messageId;
        _navigateFromMessage(initial.data);
      }

      _initTokenLifecycle();

      debugPrint('✅ PushNotificationService initialisé');
    } catch (e) {
      debugPrint('⚠️ PushNotificationService.init: $e');
      _initialized = false; // autorise un nouvel essai ultérieur
    }
  }

  void dispose() {
    _onMessageSub?.cancel();
    _openedAppSub?.cancel();
  }

  // ── Cycle de vie du token (authentification) ─────────────────────────────

  void _initTokenLifecycle() {
    // Rotation du token (réinstallation, restauration, rotation serveur).
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        registerTokenForUser(uid);
      }
    });
    // Login → enregistrement ; Logout → purge.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.uid.isNotEmpty) {
        await registerTokenForUser(user.uid);
      } else {
        await unregisterTokens();
      }
    });
    // Session déjà ouverte au démarrage.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.uid.isNotEmpty) {
      registerTokenForUser(current.uid);
    }
  }

  /// Associe le token FCM courant à l'utilisateur [uid] dans
  /// `fcm_tokens/{token}` — lu par le serveur (SDK admin) pour l'envoi.
  Future<void> registerTokenForUser(String uid) async {
    if (!isSupported || uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _registeredUid = uid;
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'uid': uid,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔔 Token FCM enregistré pour $uid');
    } catch (e) {
      debugPrint('⚠️ registerTokenForUser: $e');
    }
  }

  /// Purge les tokens de l'utilisateur courant (logout) afin que le serveur
  /// n'envoie plus de push sur cet appareil.
  Future<void> unregisterTokens() async {
    final uid = _registeredUid;
    _registeredUid = null;
    if (uid == null || uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      debugPrint('🔔 Tokens FCM purgés pour $uid');
    } catch (e) {
      debugPrint('⚠️ unregisterTokens: $e');
    }
  }

  // ── Affichage (avant-plan) ───────────────────────────────────────────────

  /// En avant-plan, FCM ne poste PAS de notification système : on affiche
  /// une bannière locale (canal high importance).
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title']?.toString();
      final body = notification?.body ?? message.data['body']?.toString();
      if (title == null || title.isEmpty) return; // rien d'affichable
      const androidDetails = AndroidNotificationDetails(
        kPushChannelId,
        kPushChannelName,
        channelDescription: 'Invitations d\'équipe, paiements et alertes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
        presentBadge: true,
      );
      await _localNotifications.show(
        id: message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch,
        title: title,
        body: body ?? '',
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('⚠️ _showForegroundNotification: $e');
    }
  }

  /// Tap sur la bannière locale (avant-plan) → navigation contextuelle.
  void _onLocalNotificationTap(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      final data = jsonDecode(payload) as Map<String, dynamic>? ?? {};
      _navigateFromMessage(data);
    } catch (e) {
      debugPrint('⚠️ _onLocalNotificationTap: $e');
    }
  }

  // ── Navigation contextuelle ──────────────────────────────────────────────

  /// Route la notification selon son type / refType :
  ///   team_invite            → Mes invitations
  ///   team_invite_accepted   → Liste des équipes
  ///   invoice                → Détail de la facture
  ///   reminder               → Rappels
  ///   subscription / wallet  → Abonnement / portefeuille
  ///   défaut                 → Centre de notifications
  void _navigateFromMessage(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? '';
      final refType = data['referenceType']?.toString() ?? '';
      final refId = data['referenceId']?.toString() ?? '';

      String route;
      if (type == 'team_invite' || refType == 'team_invite') {
        route = '/teams/invitations';
      } else if (type == 'team_invite_accepted' ||
          type == 'team_invite_declined' ||
          refType == 'team') {
        route = '/teams';
      } else if (refType == 'invoice' && refId.isNotEmpty) {
        route = '/dashboard/invoices/$refId';
      } else if (refType == 'reminder') {
        route = '/dashboard/reminders';
      } else if (refType == 'wallet') {
        route = '/wallet';
      } else if (refType == 'subscription' || type.startsWith('subscription')) {
        route = '/subscription';
      } else {
        route = '/notifications';
      }
      AppRouter.router.push(route);
    } catch (e) {
      debugPrint('⚠️ _navigateFromMessage: $e');
    }
  }
}