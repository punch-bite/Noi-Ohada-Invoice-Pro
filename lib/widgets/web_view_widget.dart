// lib/widgets/web_view_widget.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewWidget extends StatefulWidget {
  final String url;
  final String title;
  final bool showAppBar;

  const WebViewWidget({
    super.key,
    required this.url,
    this.title = 'WebView',
    this.showAppBar = true, required WebViewController controller,
  });

  @override
  State<WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<WebViewWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('Erreur WebView: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: Colors.black87,
              actions: [
                // Rafraîchir
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _controller.reload();
                  },
                ),
                // Ouvrir dans le navigateur
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () {
                    // TODO: Ouvrir dans le navigateur externe
                  },
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller, url: '',
          ),
          if (_isLoading)
            _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
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
              'Chargement... ${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}