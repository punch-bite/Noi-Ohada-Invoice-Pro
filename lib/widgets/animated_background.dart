// lib/widgets/animated_background.dart
//
// 🎬 Fond animé élégant : icônes flottantes + halos lumineux en mouvement.
// Conçu pour la landing page et les écrans premium (sans bordures ni
// ombres lourdes — uniquement des halos doux).
//
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Icône flottante décorative du fond animé.
class _FloatingIcon {
  final IconData icon;
  final Color color;
  final double size;
  final double x; // position relative 0..1
  final double y;
  final double amplitude; // amplitude de la dérive
  final double speed; // vitesse de la dérive
  final double rotationSpeed;
  final double opacity;

  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.x,
    required this.y,
    required this.amplitude,
    required this.speed,
    required this.rotationSpeed,
    required this.opacity,
  });
}

/// Fond animé : halos lumineux pulsants + icônes flottantes en dérive.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _duration = Duration(milliseconds: 3200);

  static const List<_FloatingIcon> _icons = [
    _FloatingIcon(
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF4338CA),
      size: 30, x: 0.08, y: 0.18, amplitude: 12, speed: 1.0,
      rotationSpeed: 0.4, opacity: 0.5,
    ),
    _FloatingIcon(
      icon: Icons.attach_money_rounded,
      color: Color(0xFF7C3AED),
      size: 26, x: 0.9, y: 0.15, amplitude: 16, speed: 1.3,
      rotationSpeed: 0.6, opacity: 0.45,
    ),
    _FloatingIcon(
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFFE9B949),
      size: 28, x: 0.85, y: 0.7, amplitude: 14, speed: 0.9,
      rotationSpeed: 0.5, opacity: 0.5,
    ),
    _FloatingIcon(
      icon: Icons.cloud_done_rounded,
      color: Color(0xFF4338CA),
      size: 32, x: 0.12, y: 0.78, amplitude: 18, speed: 1.1,
      rotationSpeed: 0.3, opacity: 0.4,
    ),
    _FloatingIcon(
      icon: Icons.people_alt_rounded,
      color: Color(0xFF4F46E5),
      size: 24, x: 0.25, y: 0.45, amplitude: 10, speed: 1.4,
      rotationSpeed: 0.5, opacity: 0.35,
    ),
    _FloatingIcon(
      icon: Icons.trending_up_rounded,
      color: Color(0xFF7C3AED),
      size: 26, x: 0.72, y: 0.4, amplitude: 13, speed: 0.8,
      rotationSpeed: 0.7, opacity: 0.4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Halos lumineux pulsants (pas d'ombre dure)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return CustomPaint(
              painter: _HaloPainter(isDark: isDark, t: t),
            );
          },
        ),
        // Icônes flottantes en dérive + rotation
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            return Stack(
              children: [
                for (final ic in _icons)
                  _buildFloating(ic, t, isDark),
              ],
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildFloating(_FloatingIcon ic, double t, bool isDark) {
    final driftX = math.sin(t * ic.speed) * ic.amplitude;
    final driftY = math.cos(t * ic.speed * 0.8) * ic.amplitude;
    final rotation = math.sin(t * ic.rotationSpeed) * 0.35;
    final color = isDark ? ic.color.withValues(alpha: 0.7) : ic.color;

    return Positioned(
      left: ic.x * (MediaQuery.sizeOf(context).width - 80),
      top: ic.y * (MediaQuery.sizeOf(context).height - 80),
      child: Transform.translate(
        offset: Offset(driftX, driftY),
        child: Transform.rotate(
          angle: rotation,
          child: Opacity(
            opacity: ic.opacity,
            child: Icon(ic.icon, size: ic.size, color: color),
          ),
        ),
      ),
    );
  }
}

/// Peint des halos radiaux doux qui pulsent lentement.
class _HaloPainter extends CustomPainter {
  final bool isDark;
  final double t;

  _HaloPainter({required this.isDark, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final halos = [
      (Offset(w * 0.12, h * 0.15), 0.30 + 0.08 * math.sin(t * 2 * math.pi)),
      (Offset(w * 0.88, h * 0.25), 0.34 + 0.08 * math.sin(t * 2 * math.pi + 1.5)),
      (Offset(w * 0.75, h * 0.85), 0.38 + 0.08 * math.sin(t * 2 * math.pi + 3)),
    ];

    final colors = isDark
        ? const [Color(0xFF7C6CF0), Color(0xFF9A7BFF), Color(0xFF0B0D17)]
        : const [Color(0xFF818CF8), Color(0xFFF9A8D4), Color(0xFFA5B4FC)];

    for (var i = 0; i < halos.length; i++) {
      final (center, radiusFactor) = halos[i];
      final radius = w * radiusFactor;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: isDark ? 0.22 : 0.16),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) => oldDelegate.t != t;
}
