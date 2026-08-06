// lib/services/google_drive_sync_service.dart
//
// ✅ Synchronisation Google Drive (module Business) — par EMAIL utilisateur.
//
// Ce service :
//  1. Connecte le compte Google de l'utilisateur (scope Drive).
//  2. Vérifie que l'email du compte Google correspond à celui de l'utilisateur
//     Business (liaison par email : chacun sync vers SON Drive).
//  3. Génère un backup JSON des données Firestore (clients, produits, factures).
//  4. Téléverse le fichier vers Google Drive via l'API REST (HTTP) dans un
//     dossier "OHADA Invoice Pro".
//  5. Sauvegarde l'état de synchronisation dans Firestore (collection drive_sync).
//
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class GoogleDriveSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();

  static const String _col = 'drive_sync';
  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.file';
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _driveUpload =
      'https://www.googleapis.com/upload/drive/v3/files';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? get _email => FirebaseAuth.instance.currentUser?.email;

  // ===== CHARGEMENT / SAUVEGARDE DE L'ÉTAT (lié à l'email) =====
  Future<Map<String, dynamic>?> getSyncState() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection(_col).doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('❌ getSyncState: $e');
      return null;
    }
  }

  Future<void> saveSyncState({
    required bool enabled,
    String? folderId,
    int intervalDays = 7,
    String? email,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');
    await _db.collection(_col).doc(uid).set({
      'userId': uid,
      'email': email ?? _email ?? '',
      'enabled': enabled,
      'folderId': folderId ?? '',
      'intervalDays': intervalDays,
      'lastSyncAt': enabled ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== AUTHENTIFICATION GOOGLE (scope Drive) =====
  GoogleSignIn _signIn() => GoogleSignIn(scopes: [_driveScope]);

  /// Connecte le compte Google (ou renvoie celui déjà connecté).
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    final googleSignIn = _signIn();
    // Si un compte est déjà connecté avec le scope, on le réutilise.
    if (googleSignIn.currentUser != null) {
      return googleSignIn.currentUser;
    }
    return await googleSignIn.signIn();
  }

  Future<void> signOut() => _signIn().signOut();

  /// Email du compte Google actuellement connecté (null si aucun).
  String? get connectedGoogleEmail => _signIn().currentUser?.email;

  /// Retourne le token OAuth2 du compte connecté (pour l'API Drive).
  Future<String?> _getAccessToken() async {
    final account = _signIn().currentUser;
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  // ===== VALIDATION PAR EMAIL =====
  /// Vérifie que le compte Google connecté correspond à l'email de
  /// l'utilisateur connecté (liaison par email pour la synchronisation).
  Future<String?> validateEmailBinding() async {
    final googleEmail = connectedGoogleEmail;
    if (googleEmail == null) return 'Aucun compte Google connecté';
    if (_email != null && googleEmail.toLowerCase() != _email!.toLowerCase()) {
      return 'Le compte Google ($googleEmail) ne correspond pas à votre '
          'compte ($_email). Utilisez le même email que votre abonnement.';
    }
    return null;
  }

  // ===== GÉNÉRATION DU BACKUP JSON =====
  Future<Map<String, dynamic>> buildBackup() async {
    final clients = await _databaseService.getClients();
    final products = await _databaseService.getProducts();
    final invoices = await _databaseService.getInvoices();

    return {
      'app': 'noi_ohada_invoice_pro',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'ownerEmail': _email ?? '',
      'clients': clients.map((c) => c.toMap()).toList(),
      'products': products.map((p) => p.toMap()).toList(),
      'invoices': invoices.map((i) => i.toMap()).toList(),
    };
  }

  String encodeBackupJson(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  // ===== API GOOGLE DRIVE (REST) =====
  Future<String?> _getOrCreateFolder(String token) async {
    final query = Uri.parse('$_driveApi/files').replace(queryParameters: {
      'q': "name='OHADA Invoice Pro' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      'fields': 'files(id,name)',
      'spaces': 'drive',
    });
    final listRes = await http.get(
      query,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (listRes.statusCode == 200) {
      final data = jsonDecode(listRes.body) as Map<String, dynamic>;
      final files = (data['files'] as List? ?? []);
      if (files.isNotEmpty) {
        return (files.first as Map<String, dynamic>)['id'] as String;
      }
    }
    // Créer le dossier
    final createRes = await http.post(
      Uri.parse('$_driveApi/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': 'OHADA Invoice Pro',
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (createRes.statusCode == 200) {
      final data = jsonDecode(createRes.body) as Map<String, dynamic>;
      return data['id'] as String?;
    }
    debugPrint(
        '❌ Création dossier Drive: ${createRes.statusCode} ${createRes.body}');
    return null;
  }

  /// Téléverse le backup JSON dans le dossier "OHADA Invoice Pro" de Drive.
  Future<String> uploadBackupToDrive() async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Connexion Google requise');

    // Liaison par email
    final bindingError = await validateEmailBinding();
    if (bindingError != null) throw Exception(bindingError);

    final folderId = await _getOrCreateFolder(token);
    if (folderId == null) {
      throw Exception('Impossible de créer le dossier Drive');
    }

    final backup = await buildBackup();
    final jsonStr = encodeBackupJson(backup);
    final fileName =
        'backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';

    // Multipart/related : métadonnées + contenu
    final boundary = 'ohadaBoundary${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [folderId],
      'mimeType': 'application/json',
    });
    final body = StringBuffer()
      ..write('--$boundary\r\n')
      ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
      ..write(metadata)
      ..write('\r\n--$boundary\r\n')
      ..write('Content-Type: application/json\r\n\r\n')
      ..write(jsonStr)
      ..write('\r\n--$boundary--');

    final res = await http.post(
      Uri.parse('$_driveUpload?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body.toString(),
    );
    if (res.statusCode != 200) {
      throw Exception('Échec de l\'upload Drive (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final fileId = data['id'] as String? ?? '';

    // Met à jour l'état de sync avec l'email et l'horodatage.
    await saveSyncState(enabled: true, folderId: folderId, email: _email);
    await _db.collection(_col).doc(_uid).update({
      'lastSyncAt': FieldValue.serverTimestamp(),
      'lastFileName': fileName,
    });

    return fileId;
  }
}
