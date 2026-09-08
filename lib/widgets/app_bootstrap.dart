// lib/widgets/app_bootstrap.dart
// ============================================================
//  Écran de démarrage (appelé juste après runApp, route « / »).
//
//  Refonte « soft & minimal » (2026-09) — dans l'esprit de la page
//  d'accueil (server/landing.js) :
//    • fond très doux (encre sombre / papier) + halos indigo & or
//    • logo épuré dans une tuile translucide aux coins généreux
//    • hiérarchie calme : mot-symbole, sous-titre espacé, badge OHADA
//    • aucune animation parasite (démarrage 100 % statique)
//    • s'adapte à la luminosité système (clair / sombre)
//
//  Toute l'initialisation est « best-effort » : chaque étape est protégée
//  par un try/catch et rien ne bloque l'affichage de l'interface.
// ============================================================
import 'dart:ui';

import 'package:flutter/material.dart';

/// Écran de démarrage : gère les initialisations en arrière-plan puis
/// affiche [child] dès que tout est prêt (ou après un délai max).
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

  Future<void> _initialize() async {
    try {
      // On borne l'initialisation dans le temps pour garantir que
      // l'application démarre TOUJOURS (même si un service se bloque).
      await Future.any([
        widget.onReady(
          AppBootstrapContext(
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

    // Thème suivi avant MaterialApp : luminosité système.
    final isDark = WidgetsBinding.instance.platformDispatcher
            .platformBrightness ==
        Brightness.dark;
    final s = _SplashStyle(isDark: isDark);

    // 🔧 Ce splash est rendu DIRECTEMENT sous runApp (avant le MaterialApp),
    // donc sans Directionality/MediaQuery matériel : on fournit la direction
    // de lecture explicitement, sinon Scaffold lève
    // « No Directionality widget found » en debug sur TOUTES plateformes.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: s.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Halos décoratifs très doux (cf. landing.js).
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                return Stack(
                  children: [
                    _orb(
                      color: s.accent.withValues(alpha: isDark ? 0.16 : 0.13),
                      cx: -0.16,
                      cy: -0.24,
                      size: w * 0.95,
                      w: w,
                      h: h,
                    ),
                    _orb(
                      color: s.gold.withValues(alpha: isDark ? 0.13 : 0.15),
                      cx: 1.16,
                      cy: 1.16,
                      size: w * 0.95,
                      w: w,
                      h: h,
                    ),
                    _orb(
                      color:
                          s.accent.withValues(alpha: isDark ? 0.07 : 0.06),
                      cx: 0.74,
                      cy: 0.14,
                      size: w * 0.5,
                      w: w,
                      h: h,
                    ),
                  ],
                );
              },
            ),
            // Contenu centré.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logoCard(s),
                  const SizedBox(height: 26),
                  Text(
                    'NOI OHADA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: s.ink,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'INVOICE PRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5.2,
                      color: s.faint,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _badge(s),
                  const SizedBox(height: 46),
                  // Fines amorces de progression (n'apparaissent qu'en
                  // phase d'initialisation réelle).
                  SizedBox(
                    width: 150,
                    height: 10,
                    child: Center(
                      child: _isLoading ? _loadingLine(s) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tuile « logo » translucide, coins généreux, liseré subtil.
  Widget _logoCard(_SplashStyle s) {
    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: s.isDark
              ? [
                  Colors.white.withValues(alpha: 0.07),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: s.line),
        boxShadow: [
          BoxShadow(
            color: s.accent.withValues(alpha: s.isDark ? 0.18 : 0.1),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Image.asset(
            'assets/images/splash_logo.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [s.accentDeep, s.accent],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Badge discret à point doré (cf. eyebrow de la landing).
  Widget _badge(_SplashStyle s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: s.tile,
        border: Border.all(color: s.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: s.gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: s.gold.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Conforme aux normes OHADA & SYSCOHADA',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: s.kicker,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fine barre de progression linéaire, arrondie, très douce.
  Widget _loadingLine(_SplashStyle s) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 150,
        height: 3,
        child: DecoratedBox(
          decoration: BoxDecoration(color: s.tile),
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(s.accentDeep),
          ),
        ),
      ),
    );
  }

  /// Halo radial doux positionné en fractions de l'écran.
  Widget _orb({
    required Color color,
    required double cx,
    required double cy,
    required double size,
    required double w,
    required double h,
  }) {
    return Positioned(
      left: cx * w - size / 2,
      top: cy * h - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Palette du splash (adaptative, inspirée de landing.js)
// ---------------------------------------------------------------------------
class _SplashStyle {
  _SplashStyle({required this.isDark}) {
    if (isDark) {
      bg = const Color(0xFF0E0D12);
      ink = const Color(0xFFF3EFE8);
      faint = Colors.white.withValues(alpha: 0.45);
      line = Colors.white.withValues(alpha: 0.1);
      tile = Colors.white.withValues(alpha: 0.05);
      accent = const Color(0xFF8B7CFF);
      accentDeep = const Color(0xFF6A58F0);
      kicker = const Color(0xFFC9B8FF);
      gold = const Color(0xFFE6C886);
    } else {
      bg = const Color(0xFFF7F4F9);
      ink = const Color(0xFF211D2C);
      faint = Colors.black.withValues(alpha: 0.45);
      line = Colors.black.withValues(alpha: 0.09);
      tile = Colors.black.withValues(alpha: 0.03);
      accent = const Color(0xFF5B4ED6);
      accentDeep = const Color(0xFF4338CA);
      kicker = const Color(0xFF5B4ED6);
      gold = const Color(0xFFB07C13);
    }
  }

  late final bool isDark;
  late Color bg, ink, faint, line, tile;
  late Color accent, accentDeep, kicker, gold;
}

// ---------------------------------------------------------------------------
/// Contexte d'initialisation passé au callback.
class AppBootstrapContext {
  final void Function(String status) onStatusChange;

  const AppBootstrapContext({required this.onStatusChange});
}
