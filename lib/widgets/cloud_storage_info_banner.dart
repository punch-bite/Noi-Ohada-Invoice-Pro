// lib/widgets/cloud_storage_info_banner.dart
//
// Bannière d'information sur le stockage des données.
// Depuis la migration Hive → Firestore, TOUTES les données (même plan
// gratuit) sont sauvegardées dans le cloud : plus aucune divergence
// local/cloud. Le plan n'affecte que les QUOTAS, pas le stockage.
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Affiche un récapitulatif clair du mode de stockage des données.
///
///  - Tous les plans : sauvegarde cloud sécurisée (Firestore).
///  - Plan gratuit  : rappel des quotas (clients/produits/factures).
///  - Payant        : confirmation du cloud + avantages.
class CloudStorageInfoBanner extends StatelessWidget {
  /// `true` si l'utilisateur est sur le plan gratuit.
  final bool isFreePlan;

  /// Affichage compact (pour un dashboard / liste) ou complet.
  final bool compact;

  const CloudStorageInfoBanner({
    super.key,
    this.isFreePlan = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isFreePlan) {
      return _buildBanner(
        context,
        icon: Icons.cloud_done_outlined,
        iconColor: theme.colorScheme.primary,
        title: 'Sauvegarde cloud active',
        message: compact
            ? 'Vos données sont sauvegardées dans le cloud.'
            : 'Vos fournisseurs, produits, clients et factures sont sauvegardés '
                'dans le cloud Firestore. Vous les retrouvez même si vous '
                'changez de téléphone.\n\n'
                'Le plan gratuit inclut 5 clients, 5 produits et 10 factures. '
                'Passez à Pro ou Business pour des limites supérieures.',
        actionLabel: 'Voir les plans',
        onAction: () => context.push('/subscription'),
      );
    }

    // Utilisateur avec abonnement (cloud)
    return _buildBanner(
      context,
      icon: Icons.cloud_done,
      iconColor: Colors.green,
      title: 'Abonnement actif • Sauvegarde cloud',
      message: compact
          ? 'Vos données sont sauvegardées dans le cloud.'
          : 'Vos données sont sauvegardées dans le cloud Firestore. Vous pouvez '
              'les retrouver sur n\'importe quel appareil, même si vous perdez '
              'ou changez de téléphone.',
    );
  }

  Widget _buildBanner(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
