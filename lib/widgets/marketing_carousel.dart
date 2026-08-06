// lib/widgets/marketing_carousel.dart
//
// 🎯 Carrousel marketing : slides d'information sur l'abonnement + badges.
// Affiche des offres (ex. upgrade) de façon élégante et compacte.
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/subscription_provider.dart';

class MarketingSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final String? route;

  const MarketingSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.route,
  });
}

/// Carrousel vertical de slides marketing (PageView natif, sans dépendance).
class MarketingCarousel extends StatefulWidget {
  final List<MarketingSlide> slides;
  final double height;

  const MarketingCarousel({
    super.key,
    required this.slides,
    this.height = 96,
  });

  @override
  State<MarketingCarousel> createState() => _MarketingCarouselState();
}

class _MarketingCarouselState extends State<MarketingCarousel> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final s = widget.slides[index];
              return _buildSlide(s, scheme);
            },
          ),
        ),
        if (widget.slides.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.slides.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current
                      ? scheme.primary
                      : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlide(MarketingSlide s, ColorScheme scheme) {
    return GestureDetector(
      onTap: s.route != null ? () => context.push(s.route!) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s.color.withValues(alpha: 0.22), width: 0.6),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s.icon, color: s.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: s.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (s.actionLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                s.actionLabel!,
                style: TextStyle(
                  color: s.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ],
        ),
      ),
    );
  }
}

/// Construit la liste de slides marketing selon l'abonnement actif.
///  - plan gratuit  → slide upgrade
///  - plan actif    → slide statut + rappel avantage
List<MarketingSlide> buildSubscriptionSlides(SubscriptionProvider sub) {
  final plan = sub.currentPlan;
  final isActive = sub.subscription?.isActive ?? false;
  final isFree = plan?.isFree ?? true;
  final isAdmin = false; // géré au niveau du dashboard si besoin

  if (isActive && !isFree) {
    return [
      const MarketingSlide(
        title: '✅ Abonnement actif',
        subtitle: 'Votre plan est actif. Profitez de tous vos avantages cloud.',
        icon: Icons.verified_user_rounded,
        color: Color(0xFF16A34A),
        actionLabel: 'OK',
      ),
      MarketingSlide(
        title: '⭐ ${plan?.name ?? 'Premium'}',
        subtitle: 'Sauvegarde cloud, PDF, et plus encore activés.',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF7C3AED),
        actionLabel: 'Détails',
        route: '/subscription',
      ),
    ];
  }

  return [
    const MarketingSlide(
      title: '🚀 Passez au plan Pro',
      subtitle: 'Factures illimitées, sauvegarde cloud et export PDF.',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFF4338CA),
      actionLabel: 'Voir',
      route: '/subscription',
    ),
    const MarketingSlide(
      title: '☁️ Sauvegarde cloud',
      subtitle: 'Vos données protégées sur tous vos appareils.',
      icon: Icons.cloud_done_rounded,
      color: Color(0xFF7C3AED),
      actionLabel: 'Voir',
      route: '/subscription',
    ),
  ];
}
