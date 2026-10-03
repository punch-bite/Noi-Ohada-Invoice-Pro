// lib/widgets/glass_app_background.dart
//
// Fond global discret. Les changements de thème sont interpolés pour garder
// une transition douce sans ajouter de décor qui concurrence le contenu.
//
import 'package:flutter/material.dart';

class GlassAppBackground extends StatelessWidget {
  const GlassAppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = isDark ? const Color(0xFF111916) : const Color(0xFFF4F6F2);
    final end = isDark ? const Color(0xFF17211C) : const Color(0xFFEAF0EA);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(180),
                  ),
                  color: (isDark
                          ? const Color(0xFF83C8AC)
                          : const Color(0xFF176B58))
                      .withValues(alpha: isDark ? 0.035 : 0.025),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
