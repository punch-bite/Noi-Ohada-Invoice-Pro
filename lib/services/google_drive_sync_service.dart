// lib/services/google_drive_sync_service.dart
//
// ✅ Synchronisation Google Drive (module Business).
//
// Ce service gère :
//  1. L'état de synchronisation dans Firestore (collection `drive_sync`).
//  2. La préparation d'un backup JSON des données Firestore de l'utilisateur
//     (clients, produits, factures) prêt à être envoyé sur Google Drive.
//  3. L'authentification Google via `google_sign_in` (déjà présent).
//
// NB : l'envoi effectif du fichier vers Google Drive s'appuie sur l'API Drive.
// `google_sign_in` fournit le token OAuth2 nécessaire ; pour l'upload complet
// il faut activer l'API Drive dans la console Google et brancher le package
// `googleapis` (DriveApi) avec ce token. Le backup JSON est ici sérialisé.
//
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'database_service.dart';

class GoogleDriveSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();

  static const String _col = 'drive_sync';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ===== CHARGEMENT / SAUVEGARDE DE L'ÉTAT =====
  Future<Map<String, dynamic>?> getSyncState() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection(_col).doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveSyncState({
    required bool enabled,
    String? folderId,
    int intervalDays = 7,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');
    await _db.collection(_col).doc(uid).set({
      'userId': uid,
      'enabled': enabled,
      'folderId': folderId ?? '',
      'intervalDays': intervalDays,
      'lastSyncAt': enabled ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== AUTHENTIFICATION GOOGLE =====
  /// Retourne le compte Google connecté (utilisé pour Drive).
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
        // Pour l'upload vers Drive, ajouter :
        // 'https://www.googleapis.com/auth/drive.file'
        // (et activer l'API Drive dans la console Google).
      ],
    );
    return await googleSignIn.signIn();
  }

  Future<void> signOut() {
    return GoogleSignIn().signOut();
  }

  // ===== GÉNÉRATION D'UN BACKUP JSON DES DONNÉES =====
  /// Compile les données de l'utilisateur dans un objet sérialisable.
  /// Le résultat `jsonEncode` peut être écrit dans un fichier `.json` puis
  /// téléversé sur Google Drive (méthode à brancher selon le package Drive).
  Future<Map<String, dynamic>> buildBackup() async {
    final clients = await _databaseService.getClients();
    final products = await _databaseService.getProducts();
    final invoices = await _databaseService.getInvoices();

    return {
      'app': 'noi_ohada_invoice_pro',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'clients': clients.map((c) => c.toMap()).toList(),
      'products': products.map((p) => p.toMap()).toList(),
      'invoices': invoices.map((i) => i.toMap()).toList(),
    };
  }

  String encodeBackupJson(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);
}
