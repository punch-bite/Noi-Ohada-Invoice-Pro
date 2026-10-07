// lib/widgets/admin_read_only_banner.dart
//
// 🛡️ Bandeau "Mode lecture seule administrateur".
//
// À afficher en haut des écrans d'édition (factures, clients, produits)
// quand un admin ouvre un document qui ne lui appartient PAS.
//
// Objectif : empêcher toute modification accidentelle de préserver
// l'ownership d'origine.
//
import 'package:flutter/material.dart';

class AdminReadOnlyBanner extends StatelessWidget {
  final String documentName;
  final String? ownerName;
  final VoidCallback? onTakeOwnership;

  const AdminReadOnlyBanner({
    super.key,
    required this.documentName,
    this.ownerName,
    this.onTakeOwnership,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: amber.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.visibility_outlined,
                color: amber, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode lecture seule admin',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: amber,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ownerName != null
                      ? '$documentName appartient à $ownerName'
                      : '$documentName appartient à un autre utilisateur',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withValues(alpha: 0.55),
                    height: 1.3,
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

/// 🛡️ Helper — vérifie si le mode lecture seule doit être activé.
///
/// Retourne `true` si l'utilisateur est admin ET n'est pas le propriétaire
/// du document.
bool shouldShowReadOnlyBanner({
  required bool isAdmin,
  required String currentUid,
  required String? docOwnerUid,
}) {
  if (!isAdmin) return false;
  if (docOwnerUid == null || docOwnerUid.isEmpty) return false;
  return docOwnerUid != currentUid;
}