// lib/screens/payment/mobile_money_webview.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noi_ohada_invoice_pro/models/notification.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/nochpay_service.dart';
import '../../services/notification_service.dart';

class MobileMoneyWebView extends StatefulWidget {
  final String paymentUrl;
  final String provider;
  final String transactionReference; // 🔥 Ajout : référence de la transaction
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  /// Vérificateur de statut personnalisé (ex. ENKAP). Si fourni, il remplace
  /// la vérification NoChPay : retourne le statut brut (ex. 'CONFIRMED').
  final Future<String> Function(String reference)? statusChecker;

  const MobileMoneyWebView({
    super.key,
    required this.paymentUrl,
    required this.provider,
    required this.transactionReference,
    required this.onSuccess,
    required this.onCancel,
    this.statusChecker,
  });

  @override
  State<MobileMoneyWebView> createState() => _MobileMoneyWebViewState();
}

class _MobileMoneyWebViewState extends State<MobileMoneyWebView> {
  late final WebViewController _controller;
  final NochPayService _nochPayService = NochPayService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  bool _isPaymentConfirmed = false;
  Timer? _pollingTimer;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 30; // 30 tentatives max
  static const Duration _pollingInterval = Duration(seconds: 3); // 3 secondes entre chaque tentative

  @override
  void initState() {
    super.initState();
    _initWebView();
    // Démarrer le polling de vérification
    _startPolling();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            // 🔥 Détection automatique des URLs de succès/échec
            _handleUrlRedirection(url);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() => _isLoading = false);
              _showErrorDialog(
                'Erreur de chargement: ${error.description}',
                isFatal: true,
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // ===== GESTION DES REDIRECTIONS =====
  void _handleUrlRedirection(String url) {
    final lowerUrl = url.toLowerCase();

    // 🔥 Succès : vérifier les mots-clés de confirmation
    if (lowerUrl.contains('success') ||
        lowerUrl.contains('confirmed') ||
        lowerUrl.contains('complete') ||
        lowerUrl.contains('thank-you')) {
      _handlePaymentSuccess();
      return;
    }

    // 🔥 Échec : vérifier les mots-clés d'échec
    if (lowerUrl.contains('cancel') ||
        lowerUrl.contains('failed') ||
        lowerUrl.contains('error') ||
        lowerUrl.contains('declined')) {
      _handlePaymentFailure('Le paiement a été annulé ou a échoué.');
      return;
    }

    // 🔥 Redirection vers un callback spécifique (si configuré)
    if (lowerUrl.contains('callback') || lowerUrl.contains('return')) {
      // Vérifier le statut via l'API pour confirmer
      _checkPaymentStatusFromApi();
    }
  }

  // ===== POLLING DE VÉRIFICATION =====
  void _startPolling() {
    // Vérification immédiate
    _checkPaymentStatusFromApi();

    // Timer périodique
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (_isPaymentConfirmed) {
        timer.cancel();
        return;
      }
      _pollingAttempts++;
      if (_pollingAttempts > _maxPollingAttempts) {
        timer.cancel();
        _showErrorDialog(
          'Le paiement prend trop de temps. Veuillez vérifier le statut dans votre espace client.',
          isFatal: false,
        );
        return;
      }
      _checkPaymentStatusFromApi();
    });
  }

  Future<void> _checkPaymentStatusFromApi() async {
    // Vérificateur personnalisé (ex. ENKAP) : statut brut type 'CONFIRMED'.
    if (widget.statusChecker != null) {
      try {
        final status = await widget.statusChecker!(widget.transactionReference);
        final s = status.trim().toUpperCase();
        if (s == 'CONFIRMED' || s == 'COMPLETED' || s == 'PAID') {
          await _handlePaymentSuccess();
        } else if (s == 'FAILED' || s == 'CANCELED' || s == 'CANCELLED' ||
            s == 'DECLINED') {
          await _handlePaymentFailure('Le paiement a échoué. Status: $s');
        }
        // Sinon (CREATED/INITIALISED/IN_PROGRESS) → on continue d'attendre.
      } catch (e) {
        if (_pollingAttempts > 5) debugPrint('⚠️ Polling error: $e');
      }
      return;
    }

    // Vérification NoChPay par défaut.
    try {
      final result = await _nochPayService.checkPaymentStatus(
        widget.transactionReference,
      );

      if (result['success'] == true) {
        final status = result['status'] as String?;

        if (status == 'complete' || status == 'paid' || status == 'success') {
          await _handlePaymentSuccess();
        } else if (status == 'failed' || status == 'canceled' || status == 'declined') {
          await _handlePaymentFailure('Le paiement a échoué. Status: $status');
        }
        // Sinon, on continue à attendre (status 'pending' ou 'processing')
      }
    } catch (e) {
      // Ignorer les erreurs de réseau pendant le polling
      if (_pollingAttempts > 5) {
        // Après quelques tentatives, on prévient l'utilisateur
        debugPrint('⚠️ Polling error: $e');
      }
    }
  }

  // ===== GESTION DES RÉSULTATS =====
  Future<void> _handlePaymentSuccess() async {
    if (_isPaymentConfirmed) return;

    setState(() => _isPaymentConfirmed = true);
    _pollingTimer?.cancel();

    // 🔥 Notification de succès
    await _notificationService.addNotification(
      AppNotification(
        title: '✅ Paiement réussi',
        body: 'Votre paiement via ${widget.provider} a été confirmé.',
        type: NotificationType.payment_received.toString(),
        referenceId: widget.transactionReference,
        referenceType: 'payment',
      ),
    );

    // 🔥 Marquer la transaction comme payée dans le stockage local
    await _nochPayService.removePendingTransaction(widget.transactionReference);

    // 🔥 Afficher un dialogue de succès
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✅ Paiement confirmé'),
          content: const Text(
            'Votre paiement a été effectué avec succès. Vous allez être redirigé.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSuccess();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handlePaymentFailure(String message) async {
    if (_isPaymentConfirmed) return;

    setState(() => _isPaymentConfirmed = true);
    _pollingTimer?.cancel();

    // 🔥 Notification d'échec
    await _notificationService.addNotification(
      AppNotification(
        title: '❌ Paiement échoué',
        body: message,
        type: NotificationType.system_update.toString(),
        referenceId: widget.transactionReference,
        referenceType: 'payment',
      ),
    );

    if (mounted) {
      _showErrorDialog(message, isFatal: true);
    }
  }

  // ===== DIALOGUE D'ERREUR =====
  void _showErrorDialog(String message, {bool isFatal = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isFatal,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Erreur de paiement'),
        content: Text(message),
        actions: [
          if (!isFatal)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Réessayer'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // ===== RETRY MANUEL =====
  Future<void> _retryPayment() async {
    setState(() {
      _isPaymentConfirmed = false;
      _pollingAttempts = 0;
      _isLoading = true;
    });

    // Recharger la page WebView
    await _controller.loadRequest(Uri.parse(widget.paymentUrl));
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.provider} - Paiement',
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_isPaymentConfirmed) {
              _showErrorDialog(
                'Voulez-vous vraiment annuler le paiement ?',
                isFatal: false,
              );
            } else {
              widget.onCancel();
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_isPaymentConfirmed)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: Stack(
        children: [
          // WebView principal
          WebViewWidget(controller: _controller),

          // Overlay de chargement
          if (_isLoading && !_isPaymentConfirmed)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connexion à ${widget.provider}...',
                      style: TextStyle(
                        color: const Color(0xFF1A237E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_pollingAttempts/$_maxPollingAttempts',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Indicateur de confirmation
          if (_isPaymentConfirmed)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Confirmé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}