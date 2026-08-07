// lib/main.dart ou lib/services/permission_service.dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestPermissions() async {
    // Permission Contacts
    final contactsStatus = await Permission.contacts.request();
    if (!contactsStatus.isGranted) {
      debugPrint('⚠️ Permission contacts refusée');
    }
    
    // Permission Stockage
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      debugPrint('⚠️ Permission stockage refusée');
    }
    
    // Permission Notifications (Android 13+)
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      debugPrint('⚠️ Permission notifications refusée');
    }
    
    // Permission Caméra (optionnel)
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      debugPrint('⚠️ Permission caméra refusée');
    }
  }
}