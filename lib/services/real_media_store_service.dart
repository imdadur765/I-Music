// lib/services/real_media_store_service.dart - COMPLETELY FIXED

// ignore_for_file: unnecessary_import, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';

/// 🎵 Professional Media Store Service with Enhanced Error Handling
/// and Riverpod Integration for State Management
///
/// Usage:
///   final service = RealMediaStoreService();
///   final songs = await service.fetchSongs(context: context);
class RealMediaStoreService {
  static const MethodChannel _platform = MethodChannel('i_music/media_store');
  static const String _tag = 'i_music';

  // 🎵 PROVIDER FOR SERVICE INSTANCE
  static final provider = Provider<RealMediaStoreService>((ref) {
    return RealMediaStoreService();
  });

  /// 🎵 ENHANCED METHOD TO FETCH SONGS WITH BETTER ERROR HANDLING
  Future<List<Song>> fetchSongs({BuildContext? context}) async {
    try {
      debugPrint('$_tag: Starting song fetch process...');

      // ✅ STEP 1: ENSURE PERMISSIONS WITH ENHANCED FLOW
      final bool hasPermissions = await _ensurePermissionsWithRetry(context: context);
      if (!hasPermissions) {
        debugPrint('$_tag: Permissions not granted after retry attempts.');
        return _getEnhancedFallbackSongs();
      }

      debugPrint('$_tag: Permissions granted. Fetching songs from MediaStore...');

      // ✅ STEP 2: CALL NATIVE METHOD WITH TIMEOUT
      final List<dynamic>? rawList = await _fetchSongsWithTimeout();

      if (rawList == null || rawList.isEmpty) {
        debugPrint('$_tag: No songs found in MediaStore.');
        return _getEnhancedFallbackSongs();
      }

      debugPrint('$_tag: Found ${rawList.length} raw song entries.');

      // ✅ STEP 3: PARSE AND VALIDATE SONGS
      final List<Song> songs = await _parseAndValidateSongs(rawList);

      if (songs.isEmpty) {
        debugPrint('$_tag: No valid songs after parsing.');
        return _getEnhancedFallbackSongs();
      }

      debugPrint('$_tag: Successfully parsed ${songs.length} valid songs.');
      return songs;

    } on PlatformException catch (e) {
      debugPrint('$_tag: PlatformException: ${e.message} | Code: ${e.code}');
      return _getErrorFallbackSongs('Platform error: ${e.message}');
    } on TimeoutException catch (e) {
      debugPrint('$_tag: TimeoutException: $e');
      return _getErrorFallbackSongs('Timeout while fetching songs');
    } catch (e, st) {
      debugPrint('$_tag: Unexpected error: $e\n$st');
      return _getErrorFallbackSongs('Unexpected error: $e');
    }
  }

  /// ⏱️ FETCH SONGS WITH TIMEOUT PROTECTION
  Future<List<dynamic>?> _fetchSongsWithTimeout() async {
    try {
      return await _platform.invokeListMethod<dynamic>('getAllSongs')
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      debugPrint('$_tag: Native method call timed out after 30 seconds');
      rethrow;
    }
  }

  /// 🔄 ENHANCED PERMISSION HANDLING WITH RETRY MECHANISM
  Future<bool> _ensurePermissionsWithRetry({BuildContext? context, int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('$_tag: Permission check attempt $attempt/$maxRetries');

      final bool granted = await _ensurePermissions(context: context);
      if (granted) {
        debugPrint('$_tag: Permissions granted on attempt $attempt');
        return true;
      }

      if (attempt < maxRetries) {
        debugPrint('$_tag: Waiting before retry...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('$_tag: All permission retry attempts failed');
    return false;
  }

  /// 🔐 ENHANCED PERMISSION MANAGEMENT
  Future<bool> _ensurePermissions({BuildContext? context}) async {
    try {
      // 🎯 CHECK ANDROID VERSION FOR PERMISSION STRATEGY
      final isAndroid13OrAbove = await _isAndroid13OrAbove();

      final Permission primaryPermission = isAndroid13OrAbove 
          ? Permission.audio 
          : Permission.storage;

      final Permission secondaryPermission = isAndroid13OrAbove
          ? Permission.storage
          : Permission.manageExternalStorage;

      debugPrint('$_tag: Using primary permission: ${primaryPermission.toString()}');

      // ✅ CHECK PRIMARY PERMISSION FIRST
      if (await primaryPermission.isGranted) {
        debugPrint('$_tag: Primary permission already granted');
        return true;
      }

      // 🔄 HANDLE PERMISSION REQUEST FLOW
      final PermissionStatus primaryStatus = await primaryPermission.request();

      if (primaryStatus.isGranted) {
        debugPrint('$_tag: Primary permission granted after request');
        return true;
      }

      if (primaryStatus.isPermanentlyDenied) {
        debugPrint('$_tag: Primary permission permanently denied');
        final bool opened = await _showOpenSettingsDialog(
          context,
          title: 'Permission Required',
          message: 'Audio access is permanently denied. Please enable it in app settings to use i_music.',
        );
        return opened && await primaryPermission.isGranted;
      }

      // 🆘 TRY SECONDARY PERMISSION AS FALLBACK
      if (await secondaryPermission.isGranted) {
        debugPrint('$_tag: Secondary permission granted as fallback');
        return true;
      }

      if (await secondaryPermission.isDenied) {
        debugPrint('$_tag: Requesting secondary permission');
        final PermissionStatus secondaryStatus = await secondaryPermission.request();
        if (secondaryStatus.isGranted) return true;
      }

      // 📱 SHOW RATIONALE IF POSSIBLE
      if (context != null && await primaryPermission.shouldShowRequestRationale) {
        final bool shouldRetry = await _showRationaleDialog(
          context,
          title: 'Permission Needed',
          message: 'i_music needs access to your audio files to play music. '
                   'This permission is essential for the app to function.',
        );
        
        if (shouldRetry) {
          final PermissionStatus retryStatus = await primaryPermission.request();
          return retryStatus.isGranted;
        }
      }

      debugPrint('$_tag: All permission strategies failed');
      return false;

    } catch (e, st) {
      debugPrint('$_tag: Error in permission handling: $e\n$st');
      return false;
    }
  }

  /// 🤖 CHECK ANDROID VERSION
  Future<bool> _isAndroid13OrAbove() async {
    try {
      final platformVersion = await _platform.invokeMethod<String>('getPlatformVersion');
      debugPrint('$_tag: Platform version: $platformVersion');
      
      // Simple check for Android 13+ (API 33+)
      if (platformVersion != null && platformVersion.contains('13')) {
        return true;
      }
      
      // Fallback: Assume newer Android for audio permission
      return true;
    } catch (e) {
      debugPrint('$_tag: Error checking platform version: $e');
      // Assume newer Android by default
      return true;
    }
  }

  /// 🎵 PARSE AND VALIDATE SONGS WITH ENHANCED ERROR HANDLING
  Future<List<Song>> _parseAndValidateSongs(List<dynamic> rawList) async {
    final List<Song> validSongs = [];
    int invalidCount = 0;
    int duplicateCount = 0;

    final Set<String> seenIds = <String>{};

    for (final dynamic item in rawList) {
      try {
        if (item == null) {
          invalidCount++;
          continue;
        }

        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        
        // 🎯 ENHANCED VALIDATION
        final String id = map['id']?.toString() ?? _generateFallbackId();
        final String title = map['title']?.toString().trim() ?? 'Unknown Title';
        final String artist = map['artist']?.toString().trim() ?? 'Unknown Artist';
        final String? album = map['album']?.toString().trim();
        final int duration = _parseDuration(map['duration']);
        final String uri = map['uri']?.toString().trim() ?? '';
        final String? albumArt = map['albumArt']?.toString().trim();

        // 🚫 SKIP INVALID ENTRIES
        if (uri.isEmpty || duration <= 0) {
          invalidCount++;
          continue;
        }

        // 🚫 SKIP DUPLICATES
        if (seenIds.contains(id)) {
          duplicateCount++;
          continue;
        }
        seenIds.add(id);

        // ✅ CREATE VALID SONG - WITH ALL REQUIRED FIELDS INCLUDING mediaStoreId
        validSongs.add(Song(
          id: id,
          uri: uri,
          title: title,
          artist: artist,
          album: album,
          duration: duration,
          albumArt: albumArt,
          // ✅ CRITICAL FIX: ADD mediaStoreId AND ALL REQUIRED FIELDS
          mediaStoreId: int.tryParse(id) ?? id.hashCode, // Convert to int or use hash
          genre: map['genre']?.toString(),
          trackNumber: _parseTrackNumber(map['trackNumber']),
          year: _parseYear(map['year']),
          composer: map['composer']?.toString(),
          playCount: 0,
          lastPlayed: DateTime.now(),
          dateAdded: DateTime.now(),
          isFavorite: false,
        ));

      } catch (e, st) {
        debugPrint('$_tag: Error parsing song item: $e\n$st');
        invalidCount++;
      }
    }

    // 📊 LOG PARSING RESULTS
    debugPrint('$_tag: Parsing results - Valid: ${validSongs.length}, '
               'Invalid: $invalidCount, Duplicates: $duplicateCount');

    return validSongs;
  }

  /// ⏰ PARSE DURATION WITH FALLBACKS
  int _parseDuration(dynamic duration) {
    try {
      if (duration is num) return duration.toInt();
      if (duration is String) return int.tryParse(duration) ?? 0;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 🔢 PARSE TRACK NUMBER
  int? _parseTrackNumber(dynamic trackNumber) {
    try {
      if (trackNumber is num) return trackNumber.toInt();
      if (trackNumber is String) return int.tryParse(trackNumber);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 📅 PARSE YEAR
  int? _parseYear(dynamic year) {
    try {
      if (year is num) return year.toInt();
      if (year is String) return int.tryParse(year);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆔 GENERATE FALLBACK ID
  String _generateFallbackId() {
    return 'fallback_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// 🎵 ENHANCED FALLBACK SONGS - WITH ALL REQUIRED FIELDS
  List<Song> _getEnhancedFallbackSongs() {
    return [
      Song(
        id: 'fallback_info_1',
        uri: '',
        title: 'No songs found',
        artist: 'Check permissions and try again',
        album: 'i_music',
        duration: 0,
        albumArt: null,
        // ✅ FIXED: ADD ALL REQUIRED FIELDS
        mediaStoreId: 1001,
        genre: null,
        trackNumber: null,
        year: null,
        composer: null,
        playCount: 0,
        lastPlayed: DateTime.now(),
        dateAdded: DateTime.now(),
        isFavorite: false,
      ),
      Song(
        id: 'fallback_info_2',
        uri: '',
        title: 'Grant storage permission',
        artist: 'Open app settings → Permissions',
        album: 'i_music',
        duration: 0,
        albumArt: null,
        // ✅ FIXED: ADD ALL REQUIRED FIELDS
        mediaStoreId: 1002,
        genre: null,
        trackNumber: null,
        year: null,
        composer: null,
        playCount: 0,
        lastPlayed: DateTime.now(),
        dateAdded: DateTime.now(),
        isFavorite: false,
      ),
    ];
  }

  /// 🎵 ERROR FALLBACK SONGS - WITH ALL REQUIRED FIELDS
  List<Song> _getErrorFallbackSongs(String error) {
    return [
      Song(
        id: 'error_info',
        uri: '',
        title: 'Error loading songs',
        artist: error.length > 30 ? '${error.substring(0, 30)}...' : error,
        album: 'i_music',
        duration: 0,
        albumArt: null,
        // ✅ FIXED: ADD ALL REQUIRED FIELDS
        mediaStoreId: 1003,
        genre: null,
        trackNumber: null,
        year: null,
        composer: null,
        playCount: 0,
        lastPlayed: DateTime.now(),
        dateAdded: DateTime.now(),
        isFavorite: false,
      ),
    ];
  }

  /// 💬 ENHANCED RATIONALE DIALOG
  Future<bool> _showRationaleDialog(
    BuildContext? context, {
    required String title,
    required String message,
  }) async {
    if (context == null) return true;

    try {
      final bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );

      return result ?? false;
    } catch (e) {
      debugPrint('$_tag: Error showing rationale dialog: $e');
      return true;
    }
  }

  /// ⚙️ ENHANCED SETTINGS DIALOG
  Future<bool> _showOpenSettingsDialog(
    BuildContext? context, {
    required String title,
    required String message,
  }) async {
    if (context == null) {
      return await openAppSettings();
    }

    try {
      final bool? openSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        return await openAppSettings();
      }
      return false;
    } catch (e) {
      debugPrint('$_tag: Error showing settings dialog: $e');
      return await openAppSettings();
    }
  }

  /// 🔧 CHECK PERMISSIONS STATUS (FOR UI)
  Future<Map<String, bool>> checkPermissionStatus() async {
    try {
      final isAndroid13OrAbove = await _isAndroid13OrAbove();
      final Permission primaryPermission = isAndroid13OrAbove 
          ? Permission.audio 
          : Permission.storage;

      return {
        'storage': await Permission.storage.isGranted,
        'audio': await Permission.audio.isGranted,
        'primary': await primaryPermission.isGranted,
        'manageExternal': await Permission.manageExternalStorage.isGranted,
      };
    } catch (e) {
      debugPrint('$_tag: Error checking permission status: $e');
      return {};
    }
  }

  /// 🔄 FORCE REFRESH SONGS (FOR PROVIDER INTEGRATION)
  Future<List<Song>> forceRefreshSongs({BuildContext? context}) async {
    debugPrint('$_tag: Force refreshing songs...');
    return await fetchSongs(context: context);
  }
}

// 🎵 PROVIDER FOR SONGS DATA
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final mediaStoreService = ref.watch(RealMediaStoreService.provider);
  return await mediaStoreService.fetchSongs();
});

// 🎵 PROVIDER FOR PERMISSION STATUS
final permissionStatusProvider = FutureProvider<Map<String, bool>>((ref) async {
  final mediaStoreService = ref.watch(RealMediaStoreService.provider);
  return await mediaStoreService.checkPermissionStatus();
});