// lib/main.dart ou lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestPermissions() async {
    // Permission Contacts
    final contactsStatus = await Permission.contacts.request();
    if (!contactsStatus.isGranted) {
      print('⚠️ Permission contacts refusée');
    }
    
    // Permission Stockage
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      print('⚠️ Permission stockage refusée');
    }
    
    // Permission Notifications (Android 13+)
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      print('⚠️ Permission notifications refusée');
    }
    
    // Permission Caméra (optionnel)
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      print('⚠️ Permission caméra refusée');
    }
  }
}