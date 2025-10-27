// utils/permission_utils.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  // Storage permission check karo
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
  
  // Notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  // All required permissions check karo
  static Future<bool> hasAllPermissions() async {
    final storageStatus = await Permission.manageExternalStorage.status;
    return storageStatus.isGranted;
  }
}