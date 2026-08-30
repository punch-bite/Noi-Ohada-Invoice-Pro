// lib/screens/landing/landing_screen.dart
// ============================================================
//  Landing page moderne à forte valeur marketing (motion design).
//  - Glassmorphisme + dégradé indigo/violet (design system)
//  - Animations d'entrée fluides (flutter_animate)
//  - Mise en avant des bénéfices & CTA vectorisés
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/animated_background.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Contrôleur d'orbite (facture + avatars équipe).
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  final List<_Feature> _features = const [
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
  void dispose() {
    _orbitController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    // 🎬 Fond animé (halos + icônes flottantes) sur tout l'écran.
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0D17) : const Color(0xFFF6F7FB),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ---- Barre de navigation / logo ----
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Logo réel de l'application (extrémité gauche)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
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
                              colors: [
                                theme.primaryColor,
                                theme.secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'NOI INVOICE',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.5,
                        color: theme.textColor,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/auth/login'),
                      child: Icon(
                        Icons.login_rounded,
                        color: theme.textColor,
                        size: 20,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.3, end: 0),
              ),

              // ---- Contenu scrollable / swipeable ----
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _features.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildHero(isDark, theme);
                    }
                    final featureIndex = index - 1;
                    if (featureIndex == 3) {
                      // Slide 4 : équipe cloud avec avatars en orbite
                      return _buildTeamSlide(isDark, theme);
                    }
                    if (featureIndex == 4) {
                      // Slide 5 : marketing / partage de données
                      return _buildMarketingSlide(isDark, theme);
                    }
                    return _buildFeaturePage(
                        _features[featureIndex], isDark, theme);
                  },
                ),
              ),

              // ---- Indicateurs ----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _features.length + 1,
                  (i) => _buildDot(i, theme),
                ),
              ),
              const SizedBox(height: 20),

              // ---- CTA principal ----
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    GradientButton(
                      label: 'Créer mon compte gratuitement',
                      icon: Icons.rocket_launch_rounded,
                      onPressed: () => context.push('/auth/register'),
                    )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideY(begin: 0.3, end: 0),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Données chiffrées & conformes SYSCOHADA',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: theme.subTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Section héros (slide 0) ----
  Widget _buildHero(bool isDark, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassBadge(
            label: '✨ Essai gratuit • Sans carte bancaire',
            color: const Color(0xFFE9B949),
          )
              .animate()
              .scale(begin: Offset(0.6, 0.6), end: Offset(1, 1))
              .animate()
              .fadeIn(delay: 400.ms),
          const SizedBox(height: 50),
          // 🎨 Art central : facture + modules en orbite (motion design)
          _buildHeroArt(),
          const SizedBox(height: 100),
          Text(
            'La facturation OHADA,\nsimple & puissante.'.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 14),
          Text(
            'Créez, suivez et encaissez vos factures en toute conformité '
            'SYSCOHADA, avec des paiements mobiles intégrés dès le départ.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1,
              color: theme.subTextColor,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 260.ms),
        ],
      ),
    );
  }

  /// Facture au centre + icônes de modules en orbite circulaire.
  Widget _buildHeroArt() {
    const modules = [
      (Icons.inventory_2_rounded, Color(0xFF4338CA)),
      (Icons.people_alt_rounded, Color(0xFF7C3AED)),
      (Icons.payments_rounded, Color(0xFF16A34A)),
      (Icons.cloud_done_rounded, Color(0xFF06B6D4)),
      (Icons.bar_chart_rounded, Color(0xFFE9B949)),
      (Icons.qr_code_2_rounded, Color(0xFFF97316)),
    ];
    return SizedBox(
      width: 230,
      height: 230,
      child: _OrbitRing(
        controller: _orbitController,
        radius: 108,
        reverse: false,
        center: Container(
          width: 118,
          height: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4338CA), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 64,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF4338CA),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 30,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CA3AF).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CA3AF).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TOTAL 206 500',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          for (final (icon, color) in modules)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 22, color: color),
            ),
        ],
      ),
    )
        .animate()
        .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1))
        .animate()
        .fadeIn(duration: 600.ms);
  }

  // ---- Slide 4 : ÉQUIPE — nuage + avatars en orbite rotative ----
  Widget _buildTeamSlide(bool isDark, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: _OrbitRing(
              controller: _orbitController,
              radius: 116,
              reverse: true,
              center: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(Icons.cloud_rounded,
                    color: Colors.white, size: 56),
              ),
              children: [
                for (final (name, color) in const [
                  ('A', Color(0xFF4338CA)),
                  ('B', Color(0xFF7C3AED)),
                  ('C', Color(0xFF16A34A)),
                  ('D', Color(0xFFF97316)),
                  ('E', Color(0xFFE9B949)),
                ])
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          )
              .animate()
              .scale(begin: Offset(0.85, 0.85), end: Offset(1, 1))
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 150),
          Text(
            'Travaillez en Équipe'.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.textColor,
            ),
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.25, end: 0),
          const SizedBox(height: 14),
          Text(
            'Invitez vos associés, comptables et collaborateurs. '
            'Gérez vos rôles, partagez les données et collaborez en temps réel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1,
              color: theme.subTextColor,
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }

  // ---- Slide 5 : MARKETING / PARTAGE DE DONNÉES ----
  Widget _buildMarketingSlide(bool isDark, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _marketingIcon(Icons.campaign_rounded, const Color(0xFFF59E0B),
                  delay: 0),
              const SizedBox(width: 16),
              _marketingIcon(Icons.share_rounded, const Color(0xFF4338CA),
                  delay: 150),
              const SizedBox(width: 16),
              _marketingIcon(Icons.trending_up_rounded, const Color(0xFF16A34A),
                  delay: 300),
            ],
          ),
          const SizedBox(height: 34),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.9),
                  const Color(0xFFF97316).withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statPill('+38%', 'Ventes'),
                    _statPill('2 400', 'Relances'),
                    _statPill('95%', 'Paiements'),
                  ],
                ),
                const SizedBox(height: 16),
                const Icon(Icons.auto_graph_rounded,
                    color: Colors.white, size: 44),
              ],
            ),
          )
              .animate()
              .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1))
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 150),
          Text(
            'Marketing & Partage de données'.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.textColor,
            ),
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.25, end: 0),
          const SizedBox(height: 14),
          Text(
            'Relancez vos clients, partagez vos rapports et prenez '
            'des décisions éclairées grâce à vos données.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1,
              color: theme.subTextColor,
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }

  Widget _marketingIcon(IconData icon, Color color, {required int delay}) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: color),
    ).animate().scale(
        begin: const Offset(0, 0),
        end: const Offset(1, 1),
        curve: Curves.elasticOut,
        delay: delay.ms);
  }

  Widget _statPill(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ---- Page caractéristique (slides 1 & 2) ----
  Widget _buildFeaturePage(_Feature feature, bool isDark, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  feature.accent,
                  feature.accent.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: feature.accent.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(feature.icon, size: 60, color: Colors.white),
          )
              .animate()
              .scale(begin: Offset(0.8, 0.8), end: Offset(1, 1))
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 150),
          Text(
            feature.title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.textColor,
            ),
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.25, end: 0),
          const SizedBox(height: 16),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1,
              color: theme.subTextColor,
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }

  Widget _buildDot(int index, ThemeProvider theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        gradient: _currentPage == index
            ? const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF7C3AED)])
            : const LinearGradient(
                colors: [Color(0xFFB0B7C3), Color(0xFFB0B7C3)]),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

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

/// Anneau d'éléments qui orbitent autour d'un centre (motion design).
class _OrbitRing extends StatelessWidget {
  final AnimationController controller;
  final Widget center;
  final List<Widget> children;
  final double radius;
  final bool reverse;

  const _OrbitRing({
    required this.controller,
    required this.center,
    required this.children,
    required this.radius,
    this.reverse = false,
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
            // Cercle de guidage (léger)
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.15),
                  width: 1,
                ),
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
