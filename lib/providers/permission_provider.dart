// providers/permission_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permission_service.dart';

final permissionProvider = FutureProvider<Map<String, bool>>((ref) async {
  final permissionService = PermissionService();
  return await permissionService.checkAllPermissions();
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});