// lib/widgets/enkap_checkout_dialog.dart
//
// 💳 Dialogue de paiement ENKAP : crée la commande, ouvre la page sécurisée
// E-nkap (WebView sur mobile, nouvel onglet sur web) et vérifie le statut
// automatiquement (CONFIRMED → succès, FAILED/CANCELED → échec).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/enkap_service.dart';

class EnkapCheckoutDialog extends StatefulWidget {
  final double amount;
  final String currency;
  final String description;
  final String merchantReference;
  final String providerName;
  final String? phoneNumber;
  final String? customerName;
  final String? customerEmail;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const EnkapCheckoutDialog({
    super.key,
    required this.amount,
    required this.currency,
    required this.description,
    required this.merchantReference,
    required this.providerName,
    this.phoneNumber,
    this.customerName,
    this.customerEmail,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<EnkapCheckoutDialog> createState() => _EnkapCheckoutDialogState();
}

class _EnkapCheckoutDialogState extends State<EnkapCheckoutDialog> {
  final EnkapService _enkap = EnkapService();
  String? _redirectUrl;
  String _orderTransactionId = '';
  bool _initializing = true;
  bool _loadingPage = true;
  String _error = '';
  Timer? _pollTimer;
  int _pollAttempts = 0;
  bool _done = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _initiate();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiate() async {
    Map<String, dynamic> result;
    try {
      result = await _enkap.registerOrder(
        amount: widget.amount,
        currency: widget.currency,
        description: widget.description,
        merchantReference: widget.merchantReference,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
        phoneNumber: widget.phoneNumber,
      );
    } catch (e) {
      // Filet de sécurité : ne jamais rester sur « Initialisation… »
      // (spinner infini) en cas d'exception inattendue.
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Erreur réseau : $e';
      });
      return;
    }
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _redirectUrl = result['redirectUrl'] as String? ?? '';
        _orderTransactionId = result['orderTransactionId']?.toString() ?? '';
        _initializing = false;
      });
      // Vérification du statut en arrière-plan (toutes plateformes).
      _startPolling();
    } else {
      setState(() {
        _initializing = false;
        _error = result['error'] ?? 'Erreur de paiement ENKAP';
      });
    }
  }

  // ===== POLLING (vérification automatique du statut) =====
  void _startPolling() {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _timedOut = false;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_done || !mounted) {
        timer.cancel();
        return;
      }
      _pollAttempts++;
      if (_pollAttempts > 45) {
        // Après ~3 min sans statut final, on affiche une sortie (pas de
        // spinner infini) avec un bouton pour revérifier.
        timer.cancel();
        if (mounted) setState(() => _timedOut = true);
        return;
      }
      await _checkStatus();
    });
  }

  /// Interroge le statut ENKAP : par référence marchand puis par txid
  /// (certains environnements n'exposent le statut que via le txid).
  Future<void> _checkStatus() async {
    String status = '';
    if (widget.merchantReference.isNotEmpty) {
      status = await _enkap
          .getStatus(merchantReference: widget.merchantReference);
    }
    if (status.isEmpty && _orderTransactionId.isNotEmpty) {
      status = await _enkap.getStatus(txid: _orderTransactionId);
    }
    if (!mounted || _done) return;
    if (EnkapService.isConfirmed(status)) {
      _finish(success: true);
    } else if (EnkapService.isFailed(status)) {
      _finish(success: false);
    }
  }

  /// Appelé quand la WebView navigue vers notre page de retour
  /// (`/enkap/return/<ref>?status=...`). On déclenche une vérification
  /// immédiate, et on termine si le statut est final.
  Future<void> _handleReturnNavigation(Uri uri) async {
    final path = uri.path;
    if (!path.contains('/enkap/return')) return;
    final status = uri.queryParameters['status'] ?? '';
    if (EnkapService.isConfirmed(status)) {
      _finish(success: true);
    } else if (EnkapService.isFailed(status)) {
      _finish(success: false);
    } else {
      await _checkStatus();
    }
  }

  void _finish({required bool success}) {
    if (_done) return;
    _done = true;
    _pollTimer?.cancel();
    if (success) {
      widget.onSuccess();
    } else {
      widget.onCancel();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_initializing) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initialisation du paiement…'),
        ],
      );
    }

    if (_error.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          const Text('Erreur de paiement',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onCancel();
              Navigator.pop(context);
            },
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    if (_timedOut) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_disabled,
              size: 48, color: Colors.orange.shade400),
          const SizedBox(height: 12),
          const Text(
            'Le paiement n\'a pas pu être confirmé',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vérifiez que le paiement a bien été effectué, puis réessayez.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _timedOut = false);
                    _startPolling();
                  },
                  child: const Text('Vérifier à nouveau'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _finish(success: false),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final url = _redirectUrl ?? '';
    if (url.isEmpty) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          Text('Aucune URL de paiement retournée'),
        ],
      );
    }

    if (kIsWeb) return _buildWebFallback(url, theme);

    return _buildWebView(url, theme);
  }

  // ===== MOBILE / DESKTOP : WebView intégrée =====
  Widget _buildWebView(String url, ThemeData theme) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingPage = progress < 100);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingPage = false);
          },
          onUrlChange: (change) {
            // Détection du retour E-nkap : quand la page redirige vers notre
            // URL de retour, on vérifie le statut immédiatement (plus de
            // spinner infini) et on termine si le paiement est confirmé.
            final u = Uri.tryParse(change.url ?? '');
            if (u != null) _handleReturnNavigation(u);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Paiement sécurisé E-nkap — ${widget.providerName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 380,
            width: double.infinity,
            child: Stack(
              children: [
                WebViewWidget(controller: controller),
                if (_loadingPage)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('En attente de confirmation…',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
            TextButton(
              onPressed: () => _finish(success: false),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebFallback(String url, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.language_rounded, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        const Text(
          'Finalisez le paiement sur la page sécurisée E-nkap',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Le statut sera vérifié automatiquement après le règlement '
          '(Orange Money, MTN Mobile Money ou carte).',
          style: TextStyle(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir la page de paiement'),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('En attente de confirmation…',
                style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _finish(success: false),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Annuler le paiement'),
        ),
      ],
    );
  }
}
