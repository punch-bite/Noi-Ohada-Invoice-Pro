// lib/widgets/cloud_storage_info_banner.dart
//
// Bannière d'information transparente sur le stockage des données selon
// le plan (gratuit = mémoire locale du téléphone, payant = cloud sécurisé).
import 'package:flutter/material.dart';

/// Affiche un récapitulatif clair du mode de stockage des données.
///
/// Fonctionnement :
///   - Plan gratuit : les données sont sauvegardées UNIQUEMENT dans la
///     mémoire du téléphone. Supprimer l'app → perte des fournisseurs,
///     produits, clients et factures (l'entreprise n'est pas perdue).
///   - Avec abonnement : sauvegarde dans le cloud, données récupérables
///     même en cas de perte ou de changement de téléphone.
class CloudStorageInfoBanner extends StatelessWidget {
  /// `true` si l'utilisateur est sur le plan gratuit.
  final bool isFreePlan;

  /// Affichage compact (pour un dashboards / liste) ou complet.
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
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.phone_android, color: Colors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan gratuit • Sauvegarde locale',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compact
                        ? 'Vos données sont stockées dans la mémoire de ce téléphone.'
                        : 'Vos fournisseurs, produits, clients et factures ne sont '
                            'sauvegardés QUE dans la mémoire de ce téléphone. Si vous '
                            'supprimez l\'application, ces données seront perdues '
                            '(l\'entreprise, elle, est conservée).',
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      color: Colors.orange.shade900,
                      height: 1.35,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Souscrivez à un abonnement pour sauvegarder vos données '
                      'dans le cloud et les retrouver même en cas de perte ou de '
                      'changement de téléphone.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontStyle: FontStyle.italic,
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

    // Utilisateur avec abonnement (cloud)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_done, color: Colors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Abonnement actif • Sauvegarde cloud',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos données sont sauvegardées dans le cloud. Vous pouvez les '
                  'retrouver sur n\'importe quel appareil, même si vous perdez '
                  'ou changez de téléphone.',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Colors.green.shade900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
