// lib/screens/payment/mobile_money_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MobileMoneyWebView extends StatefulWidget {
  final String paymentUrl;
  final String provider;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const MobileMoneyWebView({
    super.key,
    required this.paymentUrl,
    required this.provider,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<MobileMoneyWebView> createState() => _MobileMoneyWebViewState();
}

class _MobileMoneyWebViewState extends State<MobileMoneyWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Vérifier si le paiement est terminé
            if (url.contains('success') || url.contains('confirmed')) {
              widget.onSuccess();
              Navigator.pop(context);
            } else if (url.contains('cancel') || url.contains('failed')) {
              widget.onCancel();
              Navigator.pop(context);
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            _showErrorDialog(error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur de paiement'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel();
              Navigator.pop(context);
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.provider} - Paiement'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontSize: 14,
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