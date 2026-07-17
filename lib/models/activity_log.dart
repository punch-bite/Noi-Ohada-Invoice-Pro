// lib/models/activity_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'activity_log.g.dart'; // Généré par Hive

@JsonSerializable()
@HiveType(typeId: 17) // Utiliser un ID unique (17)
class ActivityLog {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userEmail;

  @HiveField(3)
  final String action; // 'login', 'logout', 'create_invoice', etc.

  @HiveField(4)
  final String? targetId;

  @HiveField(5)
  final String? targetType;

  @HiveField(6)
  final Map<String, dynamic>? details; // Hive supporte les Map<String, dynamic> avec les adaptateurs appropriés

  @HiveField(7)
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.action,
    this.targetId,
    this.targetType,
    this.details,
    required this.timestamp,
  });

  // ===== SÉRIALISATION FIRESTORE =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return ActivityLog(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      action: map['action'] ?? '',
      targetId: map['targetId'],
      targetType: map['targetType'],
      details: map['details'] != null ? Map<String, dynamic>.from(map['details']) : null,
      timestamp: _parseDateTime(map['timestamp']),
    );
  }

  // ===== CONSTRUCTEUR FACTORY =====

  factory ActivityLog.create({
    String? id,
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) {
    return ActivityLog(
      id: id ?? const Uuid().v4(),
      userId: userId,
      userEmail: userEmail,
      action: action,
      targetId: targetId,
      targetType: targetType,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  // ===== GETTERS UTILITAIRES =====

  /// Retourne le libellé de l'action en français
  String get actionLabel {
    switch (action) {
      case 'login':
        return 'Connexion';
      case 'logout':
        return 'Déconnexion';
      case 'register':
        return 'Inscription';
      case 'create_invoice':
        return 'Création de facture';
      case 'update_invoice':
        return 'Modification de facture';
      case 'delete_invoice':
        return 'Suppression de facture';
      case 'create_client':
        return 'Création de client';
      case 'update_client':
        return 'Modification de client';
      case 'delete_client':
        return 'Suppression de client';
      case 'create_product':
        return 'Création de produit';
      case 'update_product':
        return 'Modification de produit';
      case 'delete_product':
        return 'Suppression de produit';
      case 'create_user':
        return 'Création d\'utilisateur';
      case 'update_user':
        return 'Modification d\'utilisateur';
      case 'delete_user':
        return 'Suppression d\'utilisateur';
      case 'update_roles':
        return 'Modification des rôles';
      case 'activate_user':
        return 'Activation d\'utilisateur';
      case 'deactivate_user':
        return 'Désactivation d\'utilisateur';
      case 'admin_cancel_subscription':
        return 'Annulation d\'abonnement (admin)';
      case 'admin_extend_subscription':
        return 'Prolongation d\'abonnement (admin)';
      case 'admin_change_plan':
        return 'Changement de plan (admin)';
      case 'admin_create_subscription':
        return 'Création d\'abonnement (admin)';
      case 'password_reset':
        return 'Réinitialisation de mot de passe';
      case 'two_factor_enabled':
        return 'Activation 2FA';
      case 'two_factor_disabled':
        return 'Désactivation 2FA';
      default:
        return action;
    }
  }

  /// Retourne une icône pour l'action
  IconData get actionIcon {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'register':
        return Icons.person_add;
      case 'create_invoice':
      case 'update_invoice':
        return Icons.receipt;
      case 'delete_invoice':
        return Icons.receipt_long;
      case 'create_client':
      case 'update_client':
        return Icons.person_add;
      case 'delete_client':
        return Icons.person_remove;
      case 'create_product':
      case 'update_product':
        return Icons.inventory_2;
      case 'delete_product':
        return Icons.delete_outline;
      case 'create_user':
      case 'update_user':
        return Icons.people;
      case 'delete_user':
        return Icons.person_remove;
      case 'update_roles':
        return Icons.admin_panel_settings;
      case 'activate_user':
        return Icons.check_circle;
      case 'deactivate_user':
        return Icons.block;
      case 'admin_cancel_subscription':
      case 'admin_extend_subscription':
      case 'admin_change_plan':
      case 'admin_create_subscription':
        return Icons.subscriptions;
      case 'password_reset':
        return Icons.lock_reset;
      case 'two_factor_enabled':
        return Icons.shield;
      case 'two_factor_disabled':
        return Icons.lock_open;
      default:
        return Icons.info;
    }
  }

  /// Retourne une couleur pour l'action
  Color get actionColor {
    switch (action) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.orange;
      case 'register':
        return Colors.blue;
      case 'create_invoice':
        return Colors.purple;
      case 'update_invoice':
        return Colors.indigo;
      case 'delete_invoice':
        return Colors.red;
      case 'create_client':
        return Colors.teal;
      case 'update_client':
        return Colors.cyan;
      case 'delete_client':
        return Colors.red;
      case 'create_product':
        return Colors.amber;
      case 'update_product':
        return Colors.orange;
      case 'delete_product':
        return Colors.red;
      case 'create_user':
      case 'update_user':
        return Colors.lightBlue;
      case 'delete_user':
        return Colors.red;
      case 'update_roles':
        return Colors.deepPurple;
      case 'activate_user':
        return Colors.green;
      case 'deactivate_user':
        return Colors.red;
      case 'admin_cancel_subscription':
      case 'admin_extend_subscription':
      case 'admin_change_plan':
      case 'admin_create_subscription':
        return Colors.indigo;
      case 'password_reset':
        return Colors.orange;
      case 'two_factor_enabled':
        return Colors.green;
      case 'two_factor_disabled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Temps écoulé depuis le log (format: "il y a X minutes")
  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 30) {
      return 'il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 7) {
      return 'il y a ${(difference.inDays / 7).floor()} semaines';
    } else if (difference.inDays > 0) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }

  // ===== UTILITAIRES =====

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}