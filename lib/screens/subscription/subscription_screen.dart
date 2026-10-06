// lib/screens/subscription/subscription_screen.dart
//
// 🎨 Écran d'abonnement — refonte moderne avec sélection visuelle.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/plan.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/cloud_storage_info_banner.dart';
import 'payment_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final List<Plan> _plans = Plan.getDefaultPlans();
  Plan? _selectedPlan;

  @override
  void initState() {
    super.initState();
    // Sélectionne le plan "recommandé" par défaut
    _selectedPlan = _plans.firstWhere(
      (plan) => plan.isPopular,
      orElse: () => _plans.length > 2 ? _plans[2] : _plans.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final bgColor = themeProvider.backgroundColor;
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO ──
          SliverAppBar(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            expandedHeight: 160,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: textColor),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Abonnement',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.4,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.75),
                      const Color(0xFF7C3AED),
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
                        const Text(
                          'Passez à la vitesse\nsupérieure.',
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
                        const SizedBox(height: 8),
                        Text(
                          'Des offres adaptées à chaque étape de votre activité.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.15, end: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── CONTENU ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CloudStorageInfoBanner(
                  isFreePlan: _isFreePlan(subscriptionProvider),
                ),
                const SizedBox(height: 20),
                ..._plans.asMap().entries.map(
                      (e) => _buildPlanCard(
                        e.value,
                        e.key,
                        isDark,
                        textColor,
                        subTextColor,
                        primaryColor,
                      ),
                    ),
                const SizedBox(height: 8),
                _buildCTA(authProvider, subscriptionProvider),
                const SizedBox(height: 20),
                _buildSecurityNote(subTextColor),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CARTE PLAN
  // ═══════════════════════════════════════════════════════════
  Widget _buildPlanCard(
    Plan plan,
    int index,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final isSelected = _selectedPlan?.id == plan.id;
    final isPopular = plan.isPopular;
    final isFree = plan.isFree;
    final accent = Color(plan.accentColorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = plan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? accent
                  : isPopular
                      ? accent.withValues(alpha: 0.4)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05)),
              width: isSelected ? 2 : (isPopular ? 1.5 : 1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ──
              Row(
                children: [
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
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: isSelected ? accent : textColor,
                                ),
                              ),
                            ),
                            if (isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'RECOMMANDÉ',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (plan.tagline.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            plan.tagline,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? accent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.15)),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Description ──
              Text(
                plan.description,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 14),

              // ── Prix ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isFree)
                    Text(
                      'Gratuit',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: const Color(0xFF10B981),
                      ),
                    )
                  else ...[
                    Text(
                      plan.getPriceNumber(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        height: 1,
                        color: isSelected ? accent : textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'FCFA',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: (isSelected ? accent : textColor)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '/ ${plan.interval == 'year' ? 'an' : 'mois'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
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
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: isSelected
                              ? accent
                              : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: subTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  // ═══════════════════════════════════════════════════════════
  //  CTA PRINCIPAL
  // ═══════════════════════════════════════════════════════════
  Widget _buildCTA(
    AppAuthProvider authProvider,
    SubscriptionProvider subscriptionProvider,
  ) {
    final isFree = _selectedPlan?.isFree ?? false;
    final accent = _selectedPlan != null
        ? Color(_selectedPlan!.accentColorValue)
        : const Color(0xFF4338CA);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _selectedPlan == null
                ? null
                : isFree
                    ? () => _activateFreePlan(
                          context,
                          authProvider,
                          subscriptionProvider,
                          accent,
                        )
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentScreen(
                              plan: _selectedPlan!,
                              onPaymentComplete: () {},
                            ),
                          ),
                        );
                      },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFree
                        ? Icons.explore_rounded
                        : Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isFree
                          ? 'Activer le plan gratuit'
                          : 'Souscrire à ${_selectedPlan?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSecurityNote(Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: subTextColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Paiement sécurisé via E-nkap • Données cryptées',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  /// Détermine si l'utilisateur est sur le plan gratuit (ou aucun plan actif).
  bool _isFreePlan(SubscriptionProvider subscriptionProvider) {
    final plan = subscriptionProvider.currentPlan;
    return plan == null || plan.isFree;
  }

  void _activateFreePlan(
    BuildContext context,
    AppAuthProvider authProvider,
    SubscriptionProvider subscriptionProvider,
    Color primaryColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.explore_rounded,
                size: 18,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Plan gratuit',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avec le plan gratuit, vos données sont sauvegardées '
              'uniquement dans la mémoire de votre téléphone.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                '⚠️ Si vous supprimez l\'application, vous perdrez vos '
                'fournisseurs, produits, clients et factures. '
                'Votre entreprise est conservée.\n\n'
                'En souscrivant à un plan payant, vos données sont '
                'sauvegardées dans le cloud.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Plan gratuit activé avec succès !'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }
}