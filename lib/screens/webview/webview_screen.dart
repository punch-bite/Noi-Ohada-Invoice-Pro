// lib/screens/webview/webview_screen.dart
//
// 🌐 WebView PLEINE PAGE avec repli maîtrisé du contenu web :
//   • PAGE ENTIÈRE : AppBar minimal (titre + domaine) et le contenu web
//     occupe tout l'écran — plus de barre d'URL ni de boutons dupliqués ;
//   • FALLBACK : les erreurs de SOUS-RESSOURCES (pub, favicon, images
//     bloquées…) n'ouvrent plus de fausse alerte — seules les erreurs du
//     FRAME PRINCIPAL affichent un repli intégré (page d'erreur douce avec
//     « Réessayer » et « Ouvrir dans le navigateur ») ;
//   • Chargement : barre de progression fine sous l'AppBar ;
//   • Retour Android : remonte d'abord l'historique web, ne quitte qu'à
//     la première page.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title = 'WebView',
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _loadFailed = false;
  String _errorDetails = '';
  int _progress = 0;
  bool _canGoBack = false;

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
              _progress = progress;
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadFailed = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
            _updateNavigationState();
          },
          // 🛟 FALLBACK : on ne signale QUE l'échec du frame principal —
          // une sous-ressource bloquée (pub, police, favicon) ne doit
          // JAMAIS faire croire que la page a échoué.
          onWebResourceError: (WebResourceError error) {
            final isMainFrame = error.isForMainFrame;
            if (isMainFrame != true) return;
            setState(() {
              _loadFailed = true;
              _isLoading = false;
              _errorDetails = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    if (!mounted) return;
    setState(() => _canGoBack = canGoBack);
  }

  Future<void> _retry() async {
    setState(() {
      _loadFailed = false;
      _isLoading = true;
      _progress = 0;
    });
    try {
      await _controller.reload();
    } catch (_) {
      // Contrôleur indisponible (page fermée) : ignoré.
    }
  }

  /// 🌍 Ouvre l'URL dans le navigateur externe du système — repli
  /// universel quand le contenu web ne charge pas dans l'app.
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le navigateur'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Domaine lisible affiché sous le titre (confiance + contexte).
  String get _hostLabel {
    final uri = Uri.tryParse(widget.url);
    return (uri?.host.isNotEmpty ?? false) ? uri!.host : widget.url;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // ⬅️ Retour Android : remonte l'historique web d'abord, ne quitte
      // l'écran qu'une fois revenue à la première page.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoBack) _controller.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                _hostLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _retry,
            ),
            IconButton(
              tooltip: 'Ouvrir dans le navigateur',
              icon: const Icon(Icons.open_in_browser_rounded),
              onPressed: _openInBrowser,
            ),
          ],
          bottom: PreferredSize(
            // Barre de progression FINE : visible seulement pendant le
            // chargement, puis elle disparaît (page entière, sans overlay).
            preferredSize: const Size.fromHeight(2.5),
            child: _isLoading && !_loadFailed
                ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress / 100 : null,
                    minHeight: 2.5,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  )
                : const SizedBox(height: 2.5),
          ),
        ),
        // 🌐 Le contenu web occupe TOUTE la page.
        body: _loadFailed
            ? _buildErrorPage(scheme)
            : WebViewWidget(controller: _controller),
      ),
    );
  }

  /// 🛟 Page de REPLI douce (remplace l'ancienne dialog intrusive) :
  /// message clair + actions de récupération.
  Widget _buildErrorPage(ColorScheme scheme) {
    return Container(
      color: scheme.surface,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.wifi_off_rounded, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Le contenu web n'a pas pu être chargé",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Vérifiez votre connexion internet, puis réessayez — '
              'ou ouvrez la page dans votre navigateur.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (_errorDetails.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorDetails,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: const Text('Ouvrir dans le navigateur'),
          ),
        ],
      ),
    );
  }
}
