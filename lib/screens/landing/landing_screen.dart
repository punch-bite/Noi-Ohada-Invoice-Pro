// lib/screens/landing/landing_screen.dart
// ============================================================
//  Landing (prÃ©-connexion) â€” refonte Â« Premium Minimal Line Â»
//  (ui-ux-pro-max : storytelling progressif + line Ã©lÃ©gant)
//
//  â€¢ 6 slides Ã©purÃ©s, icÃ´nes line fines, filets 1px, accent or.
//  â€¢ Parcours OBLIGATOIRE : chaque slide doit Ãªtre vue (timer de
//    lecture ~1,5 s) avant que Â« DÃ©marrer Â» ne se dÃ©verrouille
//    vers /auth/login.
//  â€¢ Progression line + compteur Â« x / 6 Â» + pastilles.
//  â€¢ Â« Passer Â» discret (UX-safe) qui valide tout le parcours.
//  â€¢ Reduced motion respectÃ©, CTA 56px, contrastes AA.
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
//  Palette adaptative premium : papier / encre + filet or discret
// ---------------------------------------------------------------------------
class _Palette {
  _Palette({required this.isDark}) {
    if (isDark) {
      bg = const Color(0xFF0D0C11);
      ink = const Color(0xFFF4F1EA);
      muted = const Color(0xFFA39C90);
      faint = Colors.white.withValues(alpha: 0.45);
      line = Colors.white.withValues(alpha: 0.10);
      panel = Colors.white.withValues(alpha: 0.035);
      tile = Colors.white.withValues(alpha: 0.05);
      accent = const Color(0xFF8B7CFF);
      accentDeep = const Color(0xFF6A58F0);
      kicker = const Color(0xFFC9B8FF);
      gold = const Color(0xFFE6C886);
      goldStrong = const Color(0xFFE6C886);
      primaryGrad = const [Color(0xFF6A58F0), Color(0xFF4F46E5)];
    } else {
      bg = const Color(0xFFFAFAF8);
      ink = const Color(0xFF1C1917);
      muted = const Color(0xFF6B6560);
      faint = Colors.black.withValues(alpha: 0.42);
      line = Colors.black.withValues(alpha: 0.10);
      panel = Colors.black.withValues(alpha: 0.03);
      tile = Colors.white.withValues(alpha: 0.9);
      accent = const Color(0xFF5B4ED6);
      accentDeep = const Color(0xFF4338CA);
      kicker = const Color(0xFF5B4ED6);
      gold = const Color(0xFFC89B2E);
      goldStrong = const Color(0xFFA9790C);
      primaryGrad = const [Color(0xFF4338CA), Color(0xFF5B4ED6)];
    }
  }

  final bool isDark;
  late Color bg, ink, muted, faint, line, panel, tile;
  late Color accent, accentDeep, kicker, gold, goldStrong;
  late List<Color> primaryGrad;

  /// Version lisible d'une couleur module (Ã©claircie en mode sombre).
  Color module(Color c) =>
      isDark ? (Color.lerp(c, Colors.white, 0.3) ?? c) : c;
}

// ---------------------------------------------------------------------------
//  DonnÃ©es des 6 slides (line icons, ton premium)
// ---------------------------------------------------------------------------
class _Slide {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color accent;

  const _Slide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.accent,
  });
}

// ---------------------------------------------------------------------------
//  Écran — parcours obligatoire, premium minimal line
// ---------------------------------------------------------------------------
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Slides déjà « lues » (affichées ≥ temps de lecture minimal).
  final Set<int> _seen = {0};
  Timer? _readTimer;

  /// Durée minimale de lecture par slide avant validation.
  static const _minRead = Duration(milliseconds: 1500);

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.receipt_long_outlined,
      eyebrow: 'Facturation OHADA',
      title: 'La facturation,\nsimple & conforme.',
      description:
          'Créez, suivez et encaissez vos factures en toute conformité SYSCOHADA, dès le premier jour.',
      accent: Color(0xFF4338CA),
    ),
    _Slide(
      icon: Icons.verified_outlined,
      eyebrow: 'Conformité',
      title: 'Conforme OHADA,\nen toute sérénité.',
      description:
          'Documents comptables dans les règles : mentions, TVA, numérotation, traçabilité.',
      accent: Color(0xFF0E7C5B),
    ),
    _Slide(
      icon: Icons.cloud_outlined,
      eyebrow: 'Cloud',
      title: 'Vos données,\npartout avec vous.',
      description:
          'Données chiffrées et synchronisées sur tous vos appareils, même hors-ligne.',
      accent: Color(0xFF7C3AED),
    ),
    _Slide(
      icon: Icons.payments_outlined,
      eyebrow: 'Encaissements',
      title: 'Encaissez\npartout.',
      description:
          'Orange Money, MTN, Wave, carte bancaire et QR code : vos clients paient comme ils veulent.',
      accent: Color(0xFFC89B2E),
    ),
    _Slide(
      icon: Icons.group_outlined,
      eyebrow: 'Équipe',
      title: 'Travaillez\nen équipe.',
      description:
          'Invitez associés et comptables, gérez les rôles et collaborez en temps réel.',
      accent: Color(0xFF0284C7),
    ),
    _Slide(
      icon: Icons.auto_graph_outlined,
      eyebrow: 'Pilotage',
      title: 'Pilotez\nvotre activité.',
      description:
          'Relances automatiques, rapports clairs et décisions éclairées grâce à vos données.',
      accent: Color(0xFFE9B949),
    ),
  ];

  int get _total => _slides.length;
  bool get _allSeen => _seen.length >= _total;
  double get _progress => _seen.length / _total;

  @override
  void initState() {
    super.initState();
    _armReadTimer(0);
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Arme le timer de lecture : après [_minRead], la slide est marquée lue.
  void _armReadTimer(int index) {
    _readTimer?.cancel();
    _readTimer = Timer(_minRead, () {
      if (!mounted) return;
      if (_seen.add(index)) setState(() {});
    });
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    _armReadTimer(i);
  }

  void _next() {
    if (_currentPage < _total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// « Passer » discret : valide tout le parcours (UX-safe).
  void _skipAll() {
    setState(() {
      _seen.addAll(List.generate(_total, (i) => i));
    });
  }

  void _start() {
    if (!_allSeen) return;
    context.push('/auth/login');
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette(isDark: isDark);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Halos(p: p),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(p),
                _buildProgress(p),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _total,
                    itemBuilder: (context, index) =>
                        _buildSlide(_slides[index], p, reducedMotion),
                  ),
                ),
                _buildDots(p),
                _buildCta(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Barre supérieure épurée : logo + compteur + « Passer ».
  Widget _buildTopBar(_Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.gold.withValues(alpha: 0.55)),
              color: p.panel,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/splash_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.receipt_long_outlined,
                  color: p.accent,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'NOI OHADA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: p.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_seen.length} / $_total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: p.muted,
              ),
            ),
          ),
          if (!_allSeen)
            TextButton(
              onPressed: _skipAll,
              style: TextButton.styleFrom(
                foregroundColor: p.muted,
                minimumSize: const Size(48, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Passer',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  // Barre de progression line (filet or).
  Widget _buildProgress(_Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 3,
              child: LayoutBuilder(
                builder: (context, c) {
                  return Stack(
                    children: [
                      Container(color: p.line.withValues(alpha: 0.6)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeInOutCubic,
                        width: c.maxWidth * _progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [p.goldStrong, p.gold],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _allSeen
                ? 'Parcours terminé — vous pouvez démarrer'
                : 'Faites défiler pour découvrir (${_seen.length}/$_total)',
            style: TextStyle(fontSize: 11.5, color: p.faint),
          ),
        ],
      ),
    );
  }

  // Slide premium minimaliste : médaillon line + eyebrow + titre + filet.
  Widget _buildSlide(_Slide s, _Palette p, bool reducedMotion) {
    final accent = p.module(s.accent);
    final content = SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.2,
              ),
              color: accent.withValues(alpha: p.isDark ? 0.10 : 0.07),
            ),
            child: Icon(s.icon, size: 44, color: accent),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(999),
              color: p.panel,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.eyebrow.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: p.kicker,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            s.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.goldStrong, p.gold]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.65, color: p.muted),
          ),
        ],
      ),
    );

    if (reducedMotion) return content;
    return content
        .animate(key: ValueKey('slide-${s.eyebrow}'))
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.08, end: 0, duration: 380.ms);
  }

  // Pastilles : lues = or, courante = dégradé, non lues = faint.
  Widget _buildDots(_Palette p) {
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _total,
          (i) {
            final seen = _seen.contains(i);
            final current = _currentPage == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: current ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                gradient:
                    current ? LinearGradient(colors: p.primaryGrad) : null,
                color: current
                    ? null
                    : (seen
                        ? p.gold.withValues(alpha: 0.7)
                        : p.faint.withValues(alpha: 0.30)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
      ),
    );
  }

  // CTA verrouillé « Démarrer » → /auth/login.
  Widget _buildCta(_Palette p) {
    final locked = !_allSeen;
    final remaining = _total - _seen.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Opacity(
              opacity: locked ? 0.45 : 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: p.primaryGrad,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: p.gold.withValues(alpha: locked ? 0.0 : 0.45),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: locked ? null : _start,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            locked
                                ? Icons.lock_outline_rounded
                                : Icons.arrow_forward_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                locked
                                    ? 'Lisez les slides ($remaining restants)'
                                    : 'Démarrer',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Colors.white.withValues(alpha: 0.97),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentPage > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeInOutCubic,
                        )
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: p.muted,
                  minimumSize: const Size(48, 44),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16),
                    SizedBox(width: 4),
                    Text('Retour', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (_currentPage < _total - 1)
                TextButton(
                  onPressed: _next,
                  style: TextButton.styleFrom(
                    foregroundColor: p.accent,
                    minimumSize: const Size(48, 44),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Suivant',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        ],
      ),
    );
  }
}

// Halos très doux en arrière-plan.
class _Halos extends StatelessWidget {
  final _Palette p;
  const _Halos({required this.p});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            _orb(0.0, 0.0, 1.0 * w, w, h, p.accent),
            _orb(1.04, 1.08, 1.05 * w, w, h, p.gold),
          ],
        );
      },
    );
  }

  Widget _orb(double cx, double cy, double size, double w, double h,
      Color color) {
    final c = color.withValues(alpha: 0.10);
    return Positioned(
      left: cx * w - size / 2,
      top: cy * h - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c, c.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

