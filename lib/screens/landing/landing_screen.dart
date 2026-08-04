// lib/screens/landing/landing_screen.dart
// ============================================================
//  Landing page moderne à forte valeur marketing (motion design).
//  - Glassmorphisme + dégradé indigo/violet (design system)
//  - Animations d'entrée fluides (flutter_animate)
//  - Mise en avant des bénéfices & CTA vectorisés
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---- Barre de navigation / logo ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    'Noi Ohada',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: theme.textColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/auth/login'),
                    child: Text(
                      'Connexion',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.3, end: 0),
            ),

            // ---- Contenu scrollable / swipeable ----
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _features.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHero(isDark, theme);
                  }
                  return _buildFeaturePage(_features[index], isDark, theme);
                },
              ),
            ),

            // ---- Indicateurs ----
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
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
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),
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
    );
  }

  // ---- Section héros (slide 0) ----
  Widget _buildHero(bool isDark, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                Row(
                  children: [
                    _miniStat('Factures', '2 400+', const Color(0xFF4338CA)),
                    const SizedBox(width: 10),
                    _miniStat('Clients', '850+', const Color(0xFF7C3AED)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 60,
                    color: Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Votre facturation à la pointe de la conformité',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF33373F),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().scale(begin: Offset(0.9, 0.9), end: Offset(1, 1))
              .animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 32),
          Text(
            'La facturation OHADA,\nsimple & puissante.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 30,
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
              fontSize: 15,
              height: 1.5,
              color: theme.subTextColor,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 260.ms),

          const SizedBox(height: 24),
          GlassBadge(
            label: '✨ Essai gratuit • Sans carte bancaire',
            color: const Color(0xFFE9B949),
          ).animate().scale(begin: Offset(0.6, 0.6), end: Offset(1, 1))
              .animate().fadeIn(delay: 400.ms),
        ],
      ),
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
          ).animate().scale(begin: Offset(0.8, 0.8), end: Offset(1, 1))
              .animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 36),
          Text(
            feature.title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 26,
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
              fontSize: 15,
              height: 1.55,
              color: theme.subTextColor,
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
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
            ? const LinearGradient(colors: [Color(0xFF4338CA), Color(0xFF7C3AED)])
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
