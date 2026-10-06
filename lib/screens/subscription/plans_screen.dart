// lib/screens/subscription/plans_screen.dart
//
// 🎨 Refonte moderne et animée de l'écran des offres.
// Hero gradient + cards avec icônes colorées + comparaison visuelle
// + animations d'entrée en cascade + badge "POPULAIRE" animé.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/plan.dart';
import 'payment_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isInitialLoading = true);
    final subProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AppAuthProvider>();

    try {
      await subProvider.loadPlans();
      if (authProvider.user != null) {
        await subProvider.refresh();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();

    if (_isInitialLoading || subProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final plans = subProvider.plans;
    final currentSub = subProvider.subscription;
    final isAdmin = authProvider.user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(currentSub, plans, isAdmin),
          if (plans.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.builder(
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final isCurrent = currentSub != null &&
                      currentSub.planId == plan.id &&
                      currentSub.isActive;
                  return PlanCard(
                    plan: plan,
                    isCurrentPlan: isCurrent,
                    isAdmin: isAdmin,
                    index: index,
                    onSelect: () => isCurrent
                        ? _showSubscriptionDetails(subProvider)
                        : _selectPlan(plan),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  APP BAR + HERO
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(dynamic currentSub, List<Plan> plans, bool isAdmin) {
    final String badge;
    final IconData icon;
    final Color color;
    if (isAdmin) {
      badge = 'Accès administrateur illimité';
      icon = Icons.workspace_premium_rounded;
      color = const Color(0xFFBAAB6D);
    } else if (currentSub?.isActive == true) {
      badge = 'Plan actif : ${_getPlanName(plans, currentSub.planId)}';
      icon = Icons.verified_rounded;
      color = const Color(0xFF10B981);
    } else {
      badge = 'Choisissez le plan qui vous correspond';
      icon = Icons.auto_awesome_rounded;
      color = const Color(0xFF4338CA);
    }

    return SliverAppBar(
      backgroundColor: const Color(0xFFF7F4F9),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 200,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Nos offres',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: Color(0xFF17141F),
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4338CA),
                Color(0xFF6C5CE7),
                Color(0xFF7C3AED),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Des offres claires,\npour chaque ambition.',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          badge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideX(begin: 0.1, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4338CA).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFF4338CA),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun plan disponible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Veuillez réessayer plus tard',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPlan(Plan plan) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          plan: plan,
          onPaymentComplete: () {},
        ),
      ),
    );
    if (success == true && mounted) _loadData();
  }

  void _showSubscriptionDetails(SubscriptionProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubscriptionDetailsSheet(
        sub: provider.subscription!,
        plans: provider.plans,
      ),
    );
  }

  String _getPlanName(List<Plan> plans, String planId) {
    try {
      return plans.firstWhere((p) => p.id == planId).name;
    } catch (_) {
      return 'Inconnu';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CARTE PLAN MODERNE
// ═══════════════════════════════════════════════════════════════
class PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isCurrentPlan;
  final bool isAdmin;
  final int index;
  final VoidCallback onSelect;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrentPlan,
    required this.isAdmin,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = plan.isPopular;
    final isFree = plan.isFree;
    final accent = Color(plan.accentColorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: isAdmin ? null : onSelect,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrentPlan
                  ? const Color(0xFF10B981)
                  : isPopular
                      ? accent.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.06),
              width: isCurrentPlan
                  ? 2
                  : isPopular
                      ? 1.8
                      : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPopular
                    ? accent.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isPopular ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Contenu
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── En-tête : icône + nom + tagline ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône gradient
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _planIcon(plan.id),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      plan.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: Color(0xFF17141F),
                                      ),
                                    ),
                                  ),
                                  if (isCurrentPlan)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ACTUEL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (plan.tagline.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  plan.tagline,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── Description ──
                    Text(
                      plan.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Prix ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isFree) ...[
                          const Text(
                            'Gratuit',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ] else ...[
                          Text(
                            plan.getPriceNumber(),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: accent,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              'FCFA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ ${plan.interval == 'year' ? 'an' : 'mois'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Features ──
                    ...plan.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── Bouton ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: isCurrentPlan
                                ? [
                                    const Color(0xFF10B981),
                                    const Color(0xFF059669),
                                  ]
                                : [
                                    accent,
                                    accent.withValues(alpha: 0.75),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (isCurrentPlan
                                      ? const Color(0xFF10B981)
                                      : accent)
                                  .withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isAdmin ? null : onSelect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isCurrentPlan
                                    ? Icons.verified_rounded
                                    : isFree
                                        ? Icons.arrow_forward_rounded
                                        : Icons.rocket_launch_rounded,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin
                                    ? 'Accès illimité'
                                    : isCurrentPlan
                                        ? 'Plan actif'
                                        : isFree
                                            ? 'Commencer gratuitement'
                                            : 'Choisir ce plan',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Badge POPULAIRE flottant
              if (isPopular && !isCurrentPlan)
                Positioned(
                  top: -6,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'RECOMMANDÉ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                        duration: 600.ms,
                      )
                      .then()
                      .shimmer(
                        duration: 2400.ms,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 60 * index),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: 60 * index),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  IconData _planIcon(String id) {
    switch (id) {
      case 'free':
        return Icons.explore_rounded;
      case 'starter':
        return Icons.rocket_rounded;
      case 'essential':
        return Icons.workspace_premium_rounded;
      case 'pro':
        return Icons.trending_up_rounded;
      case 'business':
        return Icons.diamond_rounded;
      default:
        return Icons.card_membership_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  FEUILLE DÉTAILS ABONNEMENT
// ═══════════════════════════════════════════════════════════════
class SubscriptionDetailsSheet extends StatelessWidget {
  final dynamic sub;
  final List<Plan> plans;

  const SubscriptionDetailsSheet({
    super.key,
    required this.sub,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final currentPlan = plans.firstWhere(
      (p) => p.id == sub.planId,
      orElse: () => Plan.getFreePlan(),
    );
    final accent = Color(currentPlan.accentColorValue);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Détails de votre abonnement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow('Plan', currentPlan.name, accent, isFirst: true),
          _infoRow('Statut', sub.isActive ? 'Actif' : 'Inactif',
              const Color(0xFF10B981)),
          _infoRow('Début', format.format(sub.startDate), accent),
          _infoRow('Fin', format.format(sub.endDate), accent),
          _infoRow('Jours restants', '${sub.daysRemaining} jours',
              const Color(0xFFF59E0B)),
          if (sub.autoRenew)
            _infoRow('Renouvellement', 'Automatique', accent),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Annuler l\'abonnement'),
                        content: const Text(
                          'Voulez-vous vraiment annuler votre abonnement ? '
                          'Vous perdrez l\'accès aux fonctionnalités premium.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Non'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Oui, annuler'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context
                          .read<SubscriptionProvider>()
                          .cancelSubscription();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Abonnement annulé'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    Color accent, {
    bool isFirst = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}