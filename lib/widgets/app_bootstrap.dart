// lib/widgets/app_bootstrap.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Écran de démarrage (appelé juste après runApp).
///
/// Splash screen animé avec effet "glass" et motion design :
/// - Logo avec zoom + fondu et ombre portée animée
/// - Anneaux lumineux décoratifs animés en rotation
/// - Barre de progression fluide reflétant l'état d'initialisation.
///
/// Toute l'initialisation est "best-effort" : chaque étape est protégée par
/// un try/catch et rien ne bloque l'affichage de l'interface.
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
  // ignore: unused_field
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // On borne l'initialisation dans le temps pour garantir que
      // l'application démarre TOUJOURS (même si un service se bloque).
      await Future.any([
        widget.onReady(
          AppBootstrapContext(
            // Splash 100 % statique : on ignore les changements de statut.
            onStatusChange: (status) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
          ),
        ),
        Future.delayed(const Duration(seconds: 20)),
      ]);
    } catch (e, stack) {
      debugPrint(
          '❌ Erreur pendant l\'initialisation (appelée pour debug) : $e');
      debugPrint('📚 $stack');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _ready = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }

    // 🔧 Ce splash est rendu DIRECTEMENT sous runApp (avant le MaterialApp),
    // donc sans Directionality/MediaQuery matériel : on fournit la direction
    // de lecture explicitement, sinon Scaffold lève
    // « No Directionality widget found » en debug sur TOUTES plateformes.
    //
    // 🧊 Splash 100 % STATIQUE (demande utilisateur) : logo + titre + mention,
    // sans animation (anneaux / pulsation / zoom / fondu) ni barre de
    // progression ni texte de statut.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2A72),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A72), Color(0xFF5B3B8C), Color(0xFF7C3AED)],
            ),
          ),
          child: Stack(
            children: [
              // Halo décoratif (statique).
              Positioned(
                top: -60,
                right: -60,
                child: _buildGlow(
                  color: const Color(0xFF9A7BFF).withValues(alpha: 0.4),
                  size: 260,
                ),
              ),
              Positioned(
                bottom: -80,
                left: -70,
                child: _buildGlow(
                  color: const Color(0xFFE9B949).withValues(alpha: 0.22),
                  size: 300,
                ),
              ),
              // Logo + titre statiques.
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassLogoCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'NOI OHADA Invoice Pro',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Conforme aux normes OHADA & SYSCOHADA',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    if(_isLoading)
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassLogoCard() {
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          // 🎨 Logo réel de l'application (animé par le parent : zoom + fondu),
          // avec repli sur l'icône si l'asset est absent.
          child: Image.asset(
            'assets/images/splash_logo.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Icon(
              Icons.receipt_long,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlow({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
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
