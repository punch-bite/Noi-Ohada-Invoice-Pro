// lib/services/signature_service.dart
//
// 🖊️ Service de gestion de la signature numérique.
// Stocke la signature (image PNG en base64) dans SharedPreferences pour
// réutilisation sur toutes les factures.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignatureService {
  static const String _keyData = 'invoice_signature_data';
  static const String _keyName = 'invoice_signature_name';
  static const String _keyTitle = 'invoice_signature_title';

  /// Enregistre la signature (bytes PNG) + métadonnées en mémoire persistante.
  Future<void> saveSignature({
    required Uint8List bytes,
    String? signerName,
    String? signerTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final base64 = base64Encode(bytes);
    await prefs.setString(_keyData, base64);
    if (signerName != null) await prefs.setString(_keyName, signerName);
    if (signerTitle != null) await prefs.setString(_keyTitle, signerTitle);
    debugPrint('✅ Signature sauvegardée (${bytes.length} bytes)');
  }

  /// Charge les bytes de la signature (null si aucune).
  Future<Uint8List?> loadSignatureBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final base64 = prefs.getString(_keyData);
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  /// Retourne le nom du signataire (null si absent).
  Future<String?> getSignerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  /// Retourne le titre/fonction du signataire (null si absent).
  Future<String?> getSignerTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTitle);
  }

  /// Indique si une signature est disponible.
  Future<bool> hasSignature() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyData);
    return data != null && data.isNotEmpty;
  }

  /// Supprime la signature stockée.
  Future<void> clearSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyData);
    await prefs.remove(_keyName);
    await prefs.remove(_keyTitle);
    debugPrint('🗑️ Signature supprimée');
  }
}
