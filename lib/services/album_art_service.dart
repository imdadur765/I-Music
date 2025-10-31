import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:i_music/models/song_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart'; // ✅ ADD THIS

class AlbumArtService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // ✅ FIXED: Proper method with correct parameter types
  static Future<Uint8List?> getAlbumArt({
    required int songId, // ✅ CHANGED: int instead of String
    required String songTitle, // ✅ ADDED: For better logging
    required String artist,
  }) async {
    try {
      debugPrint('🎵 [AlbumArtService] Fetching album art for: "$songTitle" by $artist');
      debugPrint('   🔢 Song ID: $songId');

      // ✅ FIXED: Check and request permission properly
      if (!await _hasStoragePermission()) {
        debugPrint('❌ [AlbumArtService] No storage permission');
        return null;
      }

      debugPrint('   ✅ Storage permission GRANTED');
      debugPrint('   📱 Calling native method...');

      // ✅ FIXED: Pass correct parameters to native
      final result = await _channel.invokeMethod('getAlbumArt', {
        'songId': songId, // ✅ Now sending as int (matching native)
        'title': songTitle, // ✅ Added for metadata fallback
        'artist': artist,   // ✅ Added for metadata fallback
      });

      debugPrint('   📨 Native method call COMPLETED');
      
      if (result != null && result is Uint8List) {
        debugPrint('✅ [AlbumArtService] SUCCESS: Album art found');
        debugPrint('   📊 Image Data Size: ${result.length} bytes');
        return result;
      } else {
        debugPrint('❌ [AlbumArtService] NO ALBUM ART: Null or invalid data received');
        debugPrint('   🔍 Result Type: ${result?.runtimeType}');
        debugPrint('   🔍 Result Value: $result');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ [AlbumArtService] PLATFORM EXCEPTION: ${e.message}');
      debugPrint('   🏷️ Code: ${e.code}');
      debugPrint('   📝 Details: ${e.details}');
      return null;
    } catch (e) {
      debugPrint('❌ [AlbumArtService] GENERAL EXCEPTION: $e');
      return null;
    }
  }

  // ✅ FIXED: Proper storage permission check
  static Future<bool> _hasStoragePermission() async {
    try {
      final isAndroid13OrAbove = await _isAndroid13OrAbove();
      final permission = isAndroid13OrAbove ? Permission.audio : Permission.storage;
      
      debugPrint('   🔐 Checking permission: $permission');
      
      final status = await permission.status;
      debugPrint('   📊 Current Permission Status: $status');

      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        debugPrint('   📝 Requesting permission...');
        final result = await permission.request();
        debugPrint('   📋 Permission request result: $result');
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        debugPrint('   🚫 Permission permanently denied');
        debugPrint('   💡 Please enable manually in app settings');
        return false;
      } else {
        debugPrint('   ❓ Unknown permission status: $status');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Permission check error: $e');
      return false;
    }
  }

  // ✅ FIXED: Proper Android version check using device_info_plus
  static Future<bool> _isAndroid13OrAbove() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return false;
      }

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      final versionName = androidInfo.version.release;
      
      debugPrint('   📱 Android Version: $versionName (SDK $sdkVersion)');
      
      // Android 13 = SDK 33, Android 14 = SDK 34, Android 15 = SDK 35
      final isAbove = sdkVersion >= 33;
      debugPrint('   🔍 Android 13+ detected: $isAbove');
      
      return isAbove;
    } catch (e) {
      debugPrint('❌ Error checking Android version: $e');
      // Assume newer Android for safety
      return true;
    }
  }

  // ✅ FIXED: Better album art URI generator
  static String getAlbumArtUri(String? albumArtPath) {
    if (albumArtPath == null || albumArtPath.isEmpty) {
      return '';
    }
    
    // Handle both file paths and network URLs
    if (albumArtPath.startsWith('http')) {
      return albumArtPath;
    } else if (albumArtPath.startsWith('/')) {
      return 'file://$albumArtPath';
    } else {
      return albumArtPath;
    }
  }

  // ✅ FIXED: Improved hasAlbumArt check
  static Future<bool> hasAlbumArt(Song song) async {
    try {
      // First check if song has local album art path
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        debugPrint('   📁 Song has local album art path: ${song.albumArt}');
        return true;
      }
      
      // Then try to fetch from MediaStore
      debugPrint('   🔍 Checking MediaStore for album art...');
      final art = await getAlbumArt(
        songId: song.mediaStoreId, // ✅ Use mediaStoreId (int)
        songTitle: song.title,
        artist: song.artist,
      );
      
      final hasArt = art != null;
      debugPrint('   📋 MediaStore album art available: $hasArt');
      return hasArt;
    } catch (e) {
      debugPrint('❌ Error checking album art: $e');
      return false;
    }
  }

  // ✅ ADDED: Get placeholder art bytes (for default image)
  static Future<Uint8List?> getPlaceholderArt() async {
    try {
      debugPrint('   🎨 Generating placeholder album art');
      
      final result = await _channel.invokeMethod('getPlaceholderArt');
      
      if (result != null && result is Uint8List) {
        debugPrint('   ✅ Placeholder art generated: ${result.length} bytes');
        return result;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting placeholder art: $e');
      return null;
    }
  }

  // ✅ ADDED: Clear album art cache (if implemented in native)
  static Future<void> clearCache() async {
    try {
      await _channel.invokeMethod('clearAlbumArtCache');
      debugPrint('✅ Album art cache cleared');
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
    }
  }

  // ✅ ADDED: Debug method to check current permissions
  static Future<void> debugPermissions() async {
    try {
      debugPrint('🔍 === ALBUM ART SERVICE DEBUG ===');
      debugPrint('📱 Platform: ${defaultTargetPlatform}');
      
      final isAndroid13OrAbove = await _isAndroid13OrAbove();
      debugPrint('🔢 Android 13+: $isAndroid13OrAbove');
      
      final storagePermission = isAndroid13OrAbove ? Permission.audio : Permission.storage;
      final status = await storagePermission.status;
      debugPrint('🔐 Storage Permission: $status');
      
      debugPrint('🔍 === END DEBUG ===');
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }
}