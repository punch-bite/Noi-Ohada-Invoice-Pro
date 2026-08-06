// lib/widgets/glass_app_background.dart
//
// 🖼️ Fond "glass" GLOBAL appliqué à toute l'application (dans MaterialApp.builder).
// Le dégradé indigo/violet + halos couvrent tout l'écran, DERRIÈRE les écrans.
// Chaque écran devient ainsi "verre dépoli" si son Scaffold est transparent.
//
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassAppBackground extends StatelessWidget {
  const GlassAppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = isDark ? const Color(0xFF0B0D17) : const Color(0xFFEDE9FE);
    final end = isDark ? const Color(0xFF1E2433) : const Color(0xFFFDF2F8);

    return ColoredBox(
      color: isDark ? const Color(0xFF0B0D17) : const Color(0xFFF6F7FB),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dégradé de fond
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [start, end],
              ),
            ),
          ),
          // Halos lumineux doux (effet glass)
          Positioned(
            top: -100,
            right: -80,
            child: _Glow(
              color: (isDark ? const Color(0xFF7C6CF0) : const Color(0xFF818CF8))
                  .withValues(alpha: 0.22),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _Glow(
              color: (isDark ? const Color(0xFF9A7BFF) : const Color(0xFFF9A8D4))
                  .withValues(alpha: 0.18),
              size: 320,
            ),
          ),
          // Légère atténuation pour la lisibilité
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: const SizedBox.shrink(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
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
