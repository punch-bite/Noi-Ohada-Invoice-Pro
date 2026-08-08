// lib/widgets/promo_section.dart
//
// 🎉 Section publicitaire ATTRACTIVE du dashboard : carrousel à défilement
// automatique des modules (Factures Pro, Équipe, Cloud Drive, Relance).
// Incite à l'achat de factures premium et d'abonnements.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class PromoSection extends StatefulWidget {
  const PromoSection({super.key});

  @override
  State<PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<PromoSection> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  /// Slides publicitaires des modules (défilement automatique).
  List<_PromoSlide> get _slides => const [
        _PromoSlide(
          label: 'Factures Pro',
          subtitle: 'Modèles Premium pour des factures professionnelles',
          icon: Icons.palette_rounded,
          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
          route: '/templates',
        ),
        _PromoSlide(
          label: 'Équipe',
          subtitle: 'Partagez factures, produits et clients avec votre team',
          icon: Icons.groups_rounded,
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
          route: '/teams',
        ),
        _PromoSlide(
          label: 'Cloud Drive',
          subtitle: 'Sauvegarde automatique de vos données',
          icon: Icons.cloud_rounded,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          route: '/settings/drive-sync',
        ),
        _PromoSlide(
          label: 'Relance',
          subtitle: 'Boostez vos ventes avec les relances clients',
          icon: Icons.campaign_rounded,
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          route: '/dashboard/relance',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _slides.length <= 1) return;
      final next = (_current + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final slides = _slides;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Titre de la section =====
        Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Color(0xFFFF6B35), size: 20),
            const SizedBox(width: 6),
            Text(
              'Promotions & Offres',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/subscription'),
              child: Text(
                'Tout voir',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ===== Carrousel publicitaire (défilement automatique) =====
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) =>
                _buildSlide(context, slides[index]),
          ),
        ),
        const SizedBox(height: 8),

        // ===== Indicateurs de page =====
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? theme.primaryColor : theme.dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlide(BuildContext context, _PromoSlide s) {
    return GestureDetector(
      onTap: () => context.push(s.route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: s.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: s.colors.first.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(s.icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Text(
                        'Découvrir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 14),
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
}

/// Données d'une slide publicitaire.
class _PromoSlide {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String route;
  const _PromoSlide({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.route,
  });
}
