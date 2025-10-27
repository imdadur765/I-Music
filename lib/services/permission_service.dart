// services/permission_service.dart
// ignore_for_file: unused_local_variable, avoid_print

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // App start pe automatically permissions mangega
  Future<bool> requestAllPermissions() async {
    try {
      // Storage permissions - most important
      final storageStatus = await Permission.manageExternalStorage.request();
      
      // Notification permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      // Audio permission (Android 13+)
      final audioStatus = await Permission.audio.request();
      
      // Check if all essential permissions are granted
      return storageStatus.isGranted;
    } catch (e) {
      print('Permission request error: $e');
      return false;
    }
  }

  // Check current permissions status
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'storage': await Permission.manageExternalStorage.isGranted,
      'notification': await Permission.notification.isGranted,
      'audio': await Permission.audio.isGranted,
    };
  }

  // Open app settings if permissions are permanently denied
  Future<void> openAppSettingsForPermission() async {
    await openAppSettings();
  }

  // Check if we have minimum required permissions
  Future<bool> hasMinimumPermissions() async {
    return await Permission.manageExternalStorage.isGranted;
  }
}

class StorageStatus<T> {
  final T status;
  StorageStatus(this.status);
}