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

class _AppBootstrapState extends State<AppBootstrap>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  String _status = 'Préparation...';

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _ringRotation;
  // Pulsation lumineuse autour du logo
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4)),
    );
    _textSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7)),
    );
    _ringRotation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    // Halo pulsant : grandit et s'estompe en boucle.
    _pulseScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    // Grille de 4 animations de remplissage (progress biométrique).
    final step = _controller.value;
    final progress = ((step / 0.7).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    return Scaffold(
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
            // Halo décoratif animé
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
            // Anneaux en rotation autour du logo
            AnimatedBuilder(
              animation: _ringRotation,
              builder: (context, _) {
                return Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _RingsPainter(angle: _ringRotation.value),
                    ),
                  ),
                );
              },
            ),
            // Contenu central
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Carte logo glass
                  return Opacity(
                    opacity: _logoFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo avec halo lumineux pulsant
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Halo pulsant (grandit + s'estompe)
                                  AnimatedBuilder(
                                    animation: _pulseScale,
                                    builder: (context, _) {
                                      return Transform.scale(
                                        scale: _pulseScale.value,
                                        child: Opacity(
                                          opacity: _pulseOpacity.value,
                                          child: Container(
                                            width: 150,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  const Color(0xFF9A7BFF)
                                                      .withValues(alpha: 0.6),
                                                  const Color(0xFF9A7BFF)
                                                      .withValues(alpha: 0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGlassLogoCard(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
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
                                  horizontal: 14, vertical: 5),
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
                            const SizedBox(height: 44),
                            _buildProgress(progress),
                            const SizedBox(height: 14),
                            Text(
                              _status,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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

  Widget _buildProgress(double progress) {
    return Container(
      width: 220,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [Color(0xFFE9B949), Color(0xFFFFD27A)],
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

/// Peint deux anneaux concentriques en rotation pour le motion design.
class _RingsPainter extends CustomPainter {
  final double angle;
  _RingsPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    // Premier anneau
    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, paint1);

    // Arc animé en rotation (indigo / or)
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 3.14159 * 2,
        colors: [Color(0xFFE9B949), Colors.transparent],
        stops: [0.0, 0.35],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle,
      2.4,
      false,
      arcPaint..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // Arc animé en sens inverse
    final arcPaint2 = Paint()
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 3.14159 * 2,
        colors: [Color(0xFF9A7BFF), Colors.transparent],
        stops: [0.0, 0.5],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.82));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -angle * 1.4,
      1.6,
      false,
      arcPaint2..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

/// Contexte d'initialisation passé au callback.
class AppBootstrapContext {
  final void Function(String status) onStatusChange;

  const AppBootstrapContext({required this.onStatusChange});
}
