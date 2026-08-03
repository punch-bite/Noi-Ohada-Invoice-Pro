// lib/widgets/app_bootstrap.dart
import 'package:flutter/material.dart';

/// Écran de démarrage (appelé juste après runApp).
///
/// Il affiche le logo de l'application pendant que les services
/// sont initialisés en arrière-plan. Toute l'initialisation est
/// "best-effort" : chaque étape est protégée par un try/catch et
/// rien ne bloque l'affichage de l'interface.
class AppBootstrap extends StatefulWidget {
  final Future<void> Function(AppBootstrapContext context) onReady;
  final Widget child;

  const AppBootstrap({
    super.key,
    required this.onReady,
    required this.child,
  });

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  String _status = 'Préparation...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // On borne l'initialisation dans le temps pour garantir que
      // l'application démarre TOUJOURS (même si un service se bloque).
      await Future.any([
        widget.onReady(
          AppBootstrapContext(
            onStatusChange: (status) {
              if (mounted) setState(() => _status = status);
            },
          ),
        ),
        Future.delayed(const Duration(seconds: 20)),
      ]);
    } catch (e, stack) {
      debugPrint('❌ Erreur pendant l\'initialisation (appelée pour debug) : $e');
      debugPrint('📚 $stack');
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  size: 60,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'NOI OHADA Invoice Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Conforme aux normes OHADA & SYSCOHADA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contexte d'initialisation passé au callback.
class AppBootstrapContext {
  final void Function(String status) onStatusChange;

  const AppBootstrapContext({required this.onStatusChange});
}
