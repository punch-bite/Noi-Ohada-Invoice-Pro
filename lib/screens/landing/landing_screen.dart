// lib/screens/landing/landing_screen.dart
// ============================================================
//  Landing (pré-connexion) — refonte « soft & minimal » (2026-09)
//  Reprend l'esprit de la page d'accueil (server/landing.js) :
//    • fond très doux (encre sombre / papier) + halos indigo & or
//    • lueur douce qui suit le curseur, coins généreux
//    • hiérarchie typographique aérée, icônes fines
//    • palette : indigo doux #8B7CFF + or #E6C886
//    • adaptatif clair/sombre — on conserve & améliore les 6 slides
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
//  Palette adaptative inspirée de la page d'accueil (landing.js)
// ---------------------------------------------------------------------------
class _OrbSpec {
  final Color color;
  final double cx; // centre horizontal relatif 0..1
  final double cy; // centre vertical relatif 0..1
  final double sizeFactor; // taille relative à la largeur

  const _OrbSpec({
    required this.color,
    required this.cx,
    required this.cy,
    required this.sizeFactor,
  });
}

class _Palette {
  _Palette({required this.isDark}) {
    if (isDark) {
      bg = const Color(0xFF0E0D12);
      ink = const Color(0xFFF3EFE8);
      muted = const Color(0xFF9B948A);
      faint = Colors.white.withValues(alpha: 0.45);
      line = Colors.white.withValues(alpha: 0.09);
      panel = Colors.white.withValues(alpha: 0.04);
      tile = Colors.white.withValues(alpha: 0.055);
      accent = const Color(0xFF8B7CFF);
      accentDeep = const Color(0xFF6A58F0);
      kicker = const Color(0xFFC9B8FF);
      gold = const Color(0xFFE6C886);
      goldStrong = const Color(0xFFE6C886);
      aura = const Color(0xFF8B7CFF);
      auraAlpha = 0.09;
      primaryGrad = const [Color(0xFF6A58F0), Color(0xFF4F46E5)];
      titleGrad = const [
        Color(0xFFC9B8FF),
        Color(0xFF8B7CFF),
        Color(0xFFE6C886),
      ];
      orbs = const [
        _OrbSpec(color: Color(0x2E6A58F0), cx: 0.0, cy: 0.0, sizeFactor: 1.0),
        _OrbSpec(
            color: Color(0x21E6C886), cx: 1.04, cy: 1.08, sizeFactor: 1.05),
        _OrbSpec(
            color: Color(0x179A8CFF), cx: 0.8, cy: 0.42, sizeFactor: 0.55),
      ];
    } else {
      bg = const Color(0xFFF7F4F9);
      ink = const Color(0xFF211D2C);
      muted = const Color(0xFF6E6778);
      faint = Colors.black.withValues(alpha: 0.42);
      line = Colors.black.withValues(alpha: 0.08);
      panel = Colors.black.withValues(alpha: 0.035);
      tile = Colors.white.withValues(alpha: 0.82);
      accent = const Color(0xFF5B4ED6);
      accentDeep = const Color(0xFF4338CA);
      kicker = const Color(0xFF5B4ED6);
      gold = const Color(0xFFC89B2E);
      goldStrong = const Color(0xFFA9790C);
      aura = const Color(0xFF8B7CFF);
      auraAlpha = 0.10;
      primaryGrad = const [Color(0xFF4338CA), Color(0xFF5B4ED6)];
      titleGrad = const [
        Color(0xFF4338CA),
        Color(0xFF6C5CE7),
        Color(0xFFB8860B),
      ];
      orbs = const [
        _OrbSpec(color: Color(0x228B7CFF), cx: 0.0, cy: 0.0, sizeFactor: 1.0),
        _OrbSpec(
            color: Color(0x24E6C886), cx: 1.04, cy: 1.08, sizeFactor: 1.05),
        _OrbSpec(
            color: Color(0x1AC9B8FF), cx: 0.8, cy: 0.42, sizeFactor: 0.55),
      ];
    }
  }

  final bool isDark;
  late Color bg, ink, muted, faint, line, panel, tile;
  late Color accent, accentDeep, kicker, gold, goldStrong;
  late Color aura;
  late double auraAlpha;
  late List<Color> primaryGrad;
  late List<Color> titleGrad;
  late List<_OrbSpec> orbs;

  /// Version lisible d'une couleur module (éclaircie en mode sombre).
  Color module(Color c) =>
      isDark ? (Color.lerp(c, Colors.white, 0.3) ?? c) : c;
}

// ---------------------------------------------------------------------------
//  Écran
// ---------------------------------------------------------------------------
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _orbitController;

  static const List<_Feature> _features = [
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Conformité OHADA',
      description:
          'Générez vos factures et documents comptables en toute légalité et sérénité.',
      accent: Color(0xFF4338CA),
    ),
    _Feature(
      icon: Icons.cloud_done_rounded,
      title: 'Cloud Synchro',
      description:
          'Vos données financières sécurisées, à jour sur tous vos appareils.',
      accent: Color(0xFF7C3AED),
    ),
    _Feature(
      icon: Icons.qr_code_2_rounded,
      title: 'Paiements Multi',
      description:
          'Orange Money, MTN, Wave, Assoh, Kudi, carte bancaire & QR code.',
      accent: Color(0xFFE9B949),
    ),
    _Feature(
      icon: Icons.group_rounded,
      title: 'Travail en Équipe',
      description:
          'Collaborez avec vos associés, comptables et collaborateurs en temps réel.',
      accent: Color(0xFF06B6D4),
    ),
    _Feature(
      icon: Icons.campaign_rounded,
      title: 'Marketing & Relance',
      description:
          'Relancez vos clients et partagez vos données pour booster vos ventes.',
      accent: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette(isDark: isDark);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Halos(p: p),
          _PointerGlow(
            p: p,
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(p),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemCount: _features.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildHero(p);
                        final fi = index - 1;
                        if (fi == 3) return _buildTeamSlide(p);
                        if (fi == 4) return _buildMarketingSlide(p);
                        return _buildFeatureSlide(_features[fi], p);
                      },
                    ),
                  ),
                  _buildDots(p),
                  _buildCta(p),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  Barre supérieure
  // ======================================================================
  Widget _buildTopBar(_Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              'assets/images/splash_logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.accentDeep, p.accent],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
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
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bouton connexion (pilule discrète)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.push('/auth/login'),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: p.tile,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded,
                        size: 15, color: p.ink),
                    const SizedBox(width: 6),
                    Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.25, end: 0);
  }

  // ======================================================================
  //  Slide 0 — Héros
  // ======================================================================
  Widget _buildHero(_Palette p) {
    const heroTitle = 'La facturation OHADA,\nsimple & puissante.';
    final lines = heroTitle.split('\n');

    return _slideScaffold(
      p,
      children: [
        _eyebrow(p, 'Essai gratuit • Sans carte bancaire'),
        const SizedBox(height: 24),
        Text(
          lines[0],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 31,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: p.ink,
          ),
        )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.15, end: 0),
        const SizedBox(height: 3),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: p.titleGrad,
          ).createShader(bounds),
          child: Text(
            lines[1],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 31,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 180.ms)
            .slideY(begin: 0.15, end: 0),
        const SizedBox(height: 16),
        Text(
          'Créez, suivez et encaissez vos factures en toute conformité '
          'SYSCOHADA, avec des paiements mobiles intégrés dès le départ.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: p.muted,
          ),
        )
            .animate()
            .fadeIn(delay: 260.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 28),
        _buildHeroArt(p),
        const SizedBox(height: 26),
        _trustRow(p),
      ],
    );
  }

  /// Badge « eyebrow » : pastille discrète à point doré (cf. landing.js).
  Widget _eyebrow(_Palette p, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(999),
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
              boxShadow: [
                BoxShadow(
                  color: p.gold.withValues(alpha: 0.4),
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
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: p.kicker,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1))
        .animate()
        .fadeIn(duration: 400.ms);
  }

  /// Ligne de confiance (coche dorée), cf. landing.js.
  Widget _trustRow(_Palette p) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 10,
      children: ['Conforme OHADA', 'Hors-ligne inclus']
          .map(
            (t) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 15, color: p.goldStrong),
                const SizedBox(width: 6),
                Text(
                  t,
                  style: TextStyle(fontSize: 12.5, color: p.faint),
                ),
              ],
            ),
          )
          .toList(),
    )
        .animate()
        .fadeIn(delay: 300.ms);
  }

  /// Art héros : carte « facture » + modules qui orbitent lentement.
  Widget _buildHeroArt(_Palette p) {
    const modules = [
      (Icons.inventory_2_rounded, Color(0xFF4338CA)),
      (Icons.people_alt_rounded, Color(0xFF7C3AED)),
      (Icons.payments_rounded, Color(0xFF16A34A)),
      (Icons.cloud_done_rounded, Color(0xFF06B6D4)),
      (Icons.bar_chart_rounded, Color(0xFFE9B949)),
      (Icons.qr_code_2_rounded, Color(0xFFF97316)),
    ];

    final invoice = Container(
      width: 116,
      height: 148,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: p.tile,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: p.isDark ? 0.22 : 0.13),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : logo accent + barre titre
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p.accentDeep, p.accent],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [p.accentDeep, p.accent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Lignes squelettes
          _skel(p, width: double.infinity, height: 6),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _skel(p, width: double.infinity, height: 6)),
              const SizedBox(width: 8),
              _skel(p, width: 40, height: 6),
            ],
          ),
          const SizedBox(height: 7),
          _skel(p, width: 76, height: 6),
          const Spacer(),
          // Total
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: p.faint,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: p.primaryGrad,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      '206 500',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return SizedBox(
      width: 236,
      height: 236,
      child: _OrbitRing(
        controller: _orbitController,
        radius: 104,
        ringColor: p.line,
        center: invoice,
        children: [
          for (final (icon, color) in modules)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.tile,
                shape: BoxShape.circle,
                border: Border.all(color: p.line),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: p.isDark ? 0.16 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 19, color: p.module(color)),
            ),
        ],
      ),
    )
        .animate()
        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1))
        .animate()
        .fadeIn(duration: 600.ms);
  }

  Widget _skel(_Palette p, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ======================================================================
  //  Slides fonctionnalités (1, 2, 3)
  // ======================================================================
  Widget _buildFeatureSlide(_Feature f, _Palette p) {
    final accent = p.module(f.accent);
    return _slideScaffold(
      p,
      children: [
        Container(
          width: 122,
          height: 122,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: p.isDark ? 0.24 : 0.16),
                accent.withValues(alpha: 0.0),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Icon(f.icon, size: 52, color: accent),
        )
            .animate()
            .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1))
            .animate()
            .fadeIn(duration: 500.ms),
        const SizedBox(height: 28),
        Text(
          f.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: p.ink,
          ),
        )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 14),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.accentDeep, p.accent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        )
            .animate()
            .fadeIn(delay: 160.ms),
        const SizedBox(height: 14),
        Text(
          f.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: p.muted,
          ),
        )
            .animate()
            .fadeIn(delay: 220.ms)
            .slideY(begin: 0.1, end: 0),
      ],
    );
  }

  // ======================================================================
  //  Slide 4 — Équipe (nuage + avatars en orbite douce)
  // ======================================================================
  Widget _buildTeamSlide(_Palette p) {
    const members = [
      ('A', Color(0xFF4338CA)),
      ('B', Color(0xFF7C3AED)),
      ('C', Color(0xFF16A34A)),
      ('D', Color(0xFFF97316)),
      ('E', Color(0xFFE9B949)),
    ];

    final cloud = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            p.accent.withValues(alpha: p.isDark ? 0.5 : 0.16),
            p.accent.withValues(alpha: 0.0),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: p.accent.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.cloud_rounded, size: 52, color: p.accent),
    );

    return _slideScaffold(
      p,
      children: [
        SizedBox(
          width: 232,
          height: 232,
          child: _OrbitRing(
            controller: _orbitController,
            radius: 102,
            reverse: true,
            ringColor: p.line,
            center: cloud,
            children: [
              for (final (name, color) in members)
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        p.module(color),
                        p.module(color).withValues(alpha: 0.72),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: p.tile, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: p.module(color).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
        )
            .animate()
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1))
            .animate()
            .fadeIn(duration: 500.ms),
        const SizedBox(height: 26),
        Text(
          'Travaillez en Équipe',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: p.ink,
          ),
        )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 14),
        Text(
          'Invitez vos associés, comptables et collaborateurs. '
          'Gérez vos rôles, partagez les données et collaborez en temps réel.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: p.muted,
          ),
        )
            .animate()
            .fadeIn(delay: 220.ms)
            .slideY(begin: 0.1, end: 0),
      ],
    );
  }

  // ======================================================================
  //  Slide 5 — Marketing / partage de données
  // ======================================================================
  Widget _buildMarketingSlide(_Palette p) {
    return _slideScaffold(
      p,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _marketingChip(p, Icons.campaign_rounded, const Color(0xFFF59E0B),
                delay: 0),
            const SizedBox(width: 14),
            _marketingChip(p, Icons.share_rounded, const Color(0xFF4338CA),
                delay: 120),
            const SizedBox(width: 14),
            _marketingChip(p, Icons.trending_up_rounded,
                const Color(0xFF16A34A),
                delay: 240),
          ],
        ),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            color: p.tile,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: p.isDark ? 0.14 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _stat(p, '+38%', 'Ventes',
                        const Color(0xFF22A06B)),
                  ),
                  Expanded(
                    child: _stat(
                        p, '2 400', 'Relances', p.accentDeep),
                  ),
                  Expanded(
                    child: _stat(
                        p, '95%', 'Paiements', p.goldStrong),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: p.line),
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.auto_graph_rounded,
                    size: 22, color: p.accent),
              ),
            ],
          ),
        )
            .animate()
            .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1))
            .animate()
            .fadeIn(delay: 200.ms),
        const SizedBox(height: 26),
        Text(
          'Marketing & Partage de données',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: p.ink,
          ),
        )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 14),
        Text(
          'Relancez vos clients, partagez vos rapports et prenez '
          'des décisions éclairées grâce à vos données.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            color: p.muted,
          ),
        )
            .animate()
            .fadeIn(delay: 220.ms)
            .slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _marketingChip(_Palette p, IconData icon, Color color,
      {required int delay}) {
    final c = p.module(color);
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: p.tile,
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: p.isDark ? 0.22 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 27, color: c),
    ).animate().scale(
        begin: const Offset(0, 0),
        end: const Offset(1, 1),
        curve: Curves.elasticOut,
        delay: delay.ms);
  }

  Widget _stat(_Palette p, String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: p.muted),
        ),
      ],
    );
  }

  // ======================================================================
  //  Structure commune d'une slide (centrée, scroll si besoin)
  // ======================================================================
  Widget _slideScaffold(_Palette p, {required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 40),
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  // ======================================================================
  //  Indicateurs + CTA
  // ======================================================================
  Widget _buildDots(_Palette p) {
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _features.length + 1,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == i ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentPage == i
                    ? p.primaryGrad
                    : [p.faint.withValues(alpha: 0.35),
                        p.faint.withValues(alpha: 0.35)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCta(_Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Column(
        children: [
          // CTA principal
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: p.primaryGrad,
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: p.accentDeep.withValues(alpha: 0.32),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => context.push('/auth/register'),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch_rounded,
                            size: 19, color: Colors.white),
                        const SizedBox(width: 9),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Créer mon compte gratuitement',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: Colors.white.withValues(alpha: 0.97),
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
          )
              .animate()
              .fadeIn(delay: 120.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: p.faint),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Données chiffrées & conformes SYSCOHADA',
                    style: TextStyle(fontSize: 12.5, color: p.faint),
                  ),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 220.ms),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Données d'une fonctionnalité
// ---------------------------------------------------------------------------
class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });
}

// ---------------------------------------------------------------------------
//  Halos très doux en arrière-plan (cf. landing.js)
// ---------------------------------------------------------------------------
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
            for (final s in p.orbs)
              Positioned(
                left: s.cx * w - (s.sizeFactor * w) / 2,
                top: s.cy * h - (s.sizeFactor * w) / 2,
                width: s.sizeFactor * w,
                height: s.sizeFactor * w,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          s.color,
                          s.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Lueur douce qui suit le curseur / le doigt
// ---------------------------------------------------------------------------
class _PointerGlow extends StatefulWidget {
  final _Palette p;
  final Widget child;
  const _PointerGlow({required this.p, required this.child});

  @override
  State<_PointerGlow> createState() => _PointerGlowState();
}

class _PointerGlowState extends State<_PointerGlow> {
  Offset? _pos;

  void _set(Offset pos) => setState(() => _pos = pos);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth * 1.25, 620.0);
        final pos = _pos ?? Offset(c.maxWidth * 0.5, c.maxHeight * 0.3);
        return Stack(
          children: [
            // Capture les mouvements sans intercepter les gestes.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (e) => _set(e.localPosition),
                onPointerDown: (e) => _set(e.localPosition),
                onPointerHover: (e) => _set(e.localPosition),
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              left: pos.dx - size / 2,
              top: pos.dy - size / 2,
              width: size,
              height: size,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.p.aura.withValues(alpha: widget.p.auraAlpha),
                        widget.p.aura.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Anneau d'éléments orbitant autour d'un centre
// ---------------------------------------------------------------------------
class _OrbitRing extends StatelessWidget {
  final AnimationController controller;
  final Widget center;
  final List<Widget> children;
  final double radius;
  final bool reverse;
  final Color ringColor;

  const _OrbitRing({
    required this.controller,
    required this.center,
    required this.children,
    required this.radius,
    this.reverse = false,
    this.ringColor = const Color(0x00000000),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final full = 2 * math.pi;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Cercle de guidage très léger
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 1),
              ),
            ),
            center,
            for (int i = 0; i < children.length; i++)
              _OrbitingChild(
                angleBase: i * (full / children.length),
                t: reverse ? 1 - t : t,
                radius: radius,
                child: children[i],
              ),
          ],
        );
      },
    );
  }
}

class _OrbitingChild extends StatelessWidget {
  final Widget child;
  final double angleBase;
  final double t;
  final double radius;

  const _OrbitingChild({
    required this.child,
    required this.angleBase,
    required this.t,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final angle = angleBase + t * 2 * math.pi;
    return Transform.translate(
      offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
      child: child,
    );
  }
}
