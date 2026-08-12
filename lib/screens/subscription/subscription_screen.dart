// lib/screens/subscription/subscription_screen.dart
import 'package:flutter/material.dart';
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
    _selectedPlan = _plans.firstWhere(
      (plan) => plan.isPopular,
      orElse: () => _plans[1],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final shadowColor = themeProvider.shadowColor;
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Abonnement',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Text(
              'Choisissez le plan qui vous convient',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
                        Text(
              'Passez à la vitesse supérieure avec nos offres',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Bannière de transparence sur le stockage des données
            CloudStorageInfoBanner(
              isFreePlan: _isFreePlan(subscriptionProvider),
            ),
            const SizedBox(height: 16),

            // Plans
            ..._plans.map((plan) => _buildPlanCard(
              plan,
              isDark,
              textColor,
              subTextColor,
              primaryColor,
              cardColor,
              shadowColor,
            )),
            const SizedBox(height: 24),

            // Bouton de souscription (dégradé indigo→violet + flèche)
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _selectedPlan != null && !_selectedPlan!.isFree
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentScreen(
                                plan: _selectedPlan!,
                                onPaymentComplete: () {
                                  // Recharger les données après paiement
                                },
                              ),
                            ),
                          );
                        }
                      : _selectedPlan != null && _selectedPlan!.isFree
                          ? () {
                              _activateFreePlan(
                                context,
                                authProvider,
                                subscriptionProvider,
                                primaryColor,
                              );
                            }
                          : null,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _selectedPlan != null && _selectedPlan!.isFree
                                ? 'Activer le plan gratuit'
                                : 'Souscrire à ${_selectedPlan?.name ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_selectedPlan != null &&
                            !_selectedPlan!.isFree) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 16),

            // Sécurité
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: subTextColor),
                const SizedBox(width: 6),
                Text(
                  'Paiement sécurisé via E-nkap • Données cryptées',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    Plan plan,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
    Color shadowColor,
  ) {
    final isSelected = _selectedPlan?.id == plan.id;
    final isPopular = plan.isPopular;
    final isFree = plan.isFree;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPlan = plan);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isPopular
                    ? primaryColor.withValues(alpha: 0.4)
                    : (isDark ? Colors.grey[700]! : Colors.grey[200]!)),
            width: isSelected ? 2 : (isPopular ? 1.5 : 1),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 6),
              )
            else if (isPopular)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du plan
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primaryColor : textColor,
                        ),
                      ),
                      Text(
                        plan.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'POPULAIRE',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                if (isSelected)
                  const SizedBox(width: 8),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Prix
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isFree ? 'Gratuit' : plan.getFormattedPrice(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isFree ? Colors.green[700] : primaryColor,
                  ),
                ),
                if (!isFree) ...[
                  const SizedBox(width: 4),
                  Text(
                    '/ ${plan.interval == 'year' ? 'an' : 'mois'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Features
            ...plan.features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isSelected ? primaryColor : Colors.green[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    feature,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

    /// Détermine si l'utilisateur est sur le plan gratuit (ou aucun plan actif).
  bool _isFreePlan(SubscriptionProvider subscriptionProvider) {
    final plan = subscriptionProvider.currentPlan;
    // Pas d'abonnement actif ou plan gratuit → sauvegarde locale uniquement.
    return plan == null || plan.isFree;
  }

  // 🔥 UNE SEULE VERSION DE LA MÉTHODE
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
        title: const Text('Activer le plan gratuit'),
        // ⚠️ Avertissement transparent sur la sauvegarde locale.
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avec le plan gratuit, vos données sont sauvegardées '
              'uniquement dans la mémoire de votre téléphone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                '⚠️ Si vous supprimez l\'application, vous perdrez : '
                'vos fournisseurs, produits, clients et factures. '
                'Votre entreprise, elle, est conservée.\n\n'
                'En souscrivant à un plan payant, vos données sont '
                'sauvegardées dans le cloud et vous pourrez les retrouver '
                'même en cas de perte ou de changement de téléphone.',
                style: TextStyle(fontSize: 12.5, color: Colors.orange, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Simuler l'activation du plan gratuit
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Plan gratuit activé avec succès !'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
            ),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }
}