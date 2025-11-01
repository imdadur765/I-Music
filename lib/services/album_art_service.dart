import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:i_music/models/song_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AlbumArtService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // ✅ MEMORY CACHE
  static final Map<int, Uint8List> _albumArtCache = {};
  static final Map<int, Uint8List> _thumbnailCache = {};
  static final Set<int> _pendingRequests = {};

  // ✅ DISK CACHE SETUP
  static late Directory _cacheDir;
  static bool _isDiskCacheInitialized = false;

  // ✅ INITIALIZE DISK CACHE
  static Future<void> init() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDocDir.path}/album_art_cache');
      
      // Create cache directory if it doesn't exist
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      
      _isDiskCacheInitialized = true;
      debugPrint('💾 Disk cache initialized: ${_cacheDir.path}');
    } catch (e) {
      debugPrint('❌ Error initializing disk cache: $e');
    }
  }

  // ✅ DISK CACHE METHODS
  static Future<void> _saveToDiskCache(int songId, Uint8List data, {bool isThumbnail = true}) async {
    if (!_isDiskCacheInitialized) return;
    
    try {
      final fileName = isThumbnail ? 'thumb_$songId.jpg' : 'original_$songId.jpg';
      final file = File('${_cacheDir.path}/$fileName');
      await file.writeAsBytes(data);
      debugPrint('💾 Saved to disk cache: $fileName (${data.length} bytes)');
    } catch (e) {
      debugPrint('❌ Error saving to disk cache: $e');
    }
  }

  static Future<Uint8List?> _loadFromDiskCache(int songId, {bool isThumbnail = true}) async {
    if (!_isDiskCacheInitialized) return null;
    
    try {
      final fileName = isThumbnail ? 'thumb_$songId.jpg' : 'original_$songId.jpg';
      final file = File('${_cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final data = await file.readAsBytes();
        debugPrint('📂 Loaded from disk cache: $fileName (${data.length} bytes)');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading from disk cache: $e');
      return null;
    }
  }

  // ✅ UPDATED ORIGINAL METHOD - WITH DISK CACHE
  static Future<Uint8List?> getAlbumArt({
    required int songId,
    required String songTitle,
    required String artist,
  }) async {
    try {
      debugPrint('🎵 [AlbumArtService] Fetching album art for: "$songTitle"');
      
      // ✅ 1. PEHLE MEMORY CACHE CHECK
      if (_albumArtCache.containsKey(songId)) {
        debugPrint('✅ [MEMORY CACHE HIT] Album art from memory for: $songTitle');
        return _albumArtCache[songId];
      }
      
      // ✅ 2. PHIR DISK CACHE CHECK
      final diskCached = await _loadFromDiskCache(songId, isThumbnail: false);
      if (diskCached != null) {
        debugPrint('✅ [DISK CACHE HIT] Album art from disk for: $songTitle');
        // Memory cache mein bhi save karo for fast access
        _albumArtCache[songId] = diskCached;
        return diskCached;
      }
      
      // ✅ 3. DUPLICATE REQUEST ROKNE KE LIYE
      if (_pendingRequests.contains(songId)) {
        debugPrint('⏳ [SKIP] Already loading album art for: $songTitle');
        return null;
      }
      
      _pendingRequests.add(songId);

      // ✅ 4. PERMISSION CHECK
      if (!await _hasStoragePermission()) {
        debugPrint('❌ [AlbumArtService] No storage permission');
        _pendingRequests.remove(songId);
        return null;
      }

      debugPrint('   ✅ Storage permission GRANTED');
      debugPrint('   📱 Calling native method...');

      // ✅ 5. NATIVE CALL (LAST RESORT)
      final result = await _channel.invokeMethod('getAlbumArt', {
        'songId': songId,
        'title': songTitle,
        'artist': artist,
      });

      debugPrint('   📨 Native method call COMPLETED');
      
      _pendingRequests.remove(songId);
      
      if (result != null && result is Uint8List) {
        debugPrint('✅ [AlbumArtService] SUCCESS: Album art found');
        debugPrint('   📊 Image Data Size: ${result.length} bytes');
        
        // ✅ MEMORY CACHE MEIN SAVE KARO
        _albumArtCache[songId] = result;
        
        // ✅ DISK CACHE MEIN BHI SAVE KARO (LIFETIME STORAGE)
        await _saveToDiskCache(songId, result, isThumbnail: false);
        
        return result;
      } else {
        debugPrint('❌ [AlbumArtService] NO ALBUM ART: Null or invalid data received');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ [AlbumArtService] PLATFORM EXCEPTION: ${e.message}');
      _pendingRequests.remove(songId);
      return null;
    } catch (e) {
      debugPrint('❌ [AlbumArtService] GENERAL EXCEPTION: $e');
      _pendingRequests.remove(songId);
      return null;
    }
  }

  // ✅ UPDATED THUMBNAIL METHOD - WITH DISK CACHE
  static Future<Uint8List?> getThumbnail({
    required int songId,
    required String songTitle,
    required String artist,
  }) async {
    try {
      debugPrint('🖼️ [Thumbnail] Requesting thumbnail for: "$songTitle"');
      
      // ✅ 1. PEHLE MEMORY CACHE CHECK
      if (_thumbnailCache.containsKey(songId)) {
        debugPrint('✅ [THUMBNAIL MEMORY CACHE HIT] Instant thumbnail for: $songTitle');
        return _thumbnailCache[songId];
      }
      
      // ✅ 2. PHIR DISK CACHE CHECK
      final diskCachedThumbnail = await _loadFromDiskCache(songId, isThumbnail: true);
      if (diskCachedThumbnail != null) {
        debugPrint('✅ [THUMBNAIL DISK CACHE HIT] Thumbnail from disk for: $songTitle');
        _thumbnailCache[songId] = diskCachedThumbnail;
        return diskCachedThumbnail;
      }
      
      // ✅ 3. ORIGINAL IMAGE LOAD KARO (ya cache se lo)
      final original = await getAlbumArt(
        songId: songId,
        songTitle: songTitle,
        artist: artist,
      );
      
      if (original != null) {
        // ✅ THUMBNAIL BANAO
        final thumbnail = await _generateThumbnail(original);
        
        // ✅ MEMORY CACHE MEIN SAVE KARO
        _thumbnailCache[songId] = thumbnail;
        
        // ✅ DISK CACHE MEIN BHI SAVE KARO (LIFETIME STORAGE)
        await _saveToDiskCache(songId, thumbnail, isThumbnail: true);
        
        debugPrint('✅ [Thumbnail] Generated: ${original.length} → ${thumbnail.length} bytes');
        return thumbnail;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ [Thumbnail] Error: $e');
      return null;
    }
  }

  // ✅ THUMBNAIL GENERATOR (Optimized)
  static Future<Uint8List> _generateThumbnail(Uint8List originalBytes) async {
    try {
      // Skip thumbnail generation for very small images
      if (originalBytes.length <= 2000) {
        return originalBytes;
      }

      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Smaller size for better performance (120x120)
      const targetSize = 120;
      final aspectRatio = image.width / image.height;
      
      int targetWidth, targetHeight;
      
      if (image.width > image.height) {
        targetWidth = targetSize;
        targetHeight = (targetSize / aspectRatio).round();
      } else {
        targetHeight = targetSize;
        targetWidth = (targetSize * aspectRatio).round();
      }
      
      // Ensure minimum size
      targetWidth = targetWidth.clamp(80, 150);
      targetHeight = targetHeight.clamp(80, 150);
      
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTRB(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );
      
      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(targetWidth, targetHeight);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      // Cleanup
      image.dispose();
      codec.dispose();
      
      final thumbnailBytes = byteData!.buffer.asUint8List();
      debugPrint('🎨 Thumbnail generated: ${originalBytes.length} → ${thumbnailBytes.length} bytes');
      
      return thumbnailBytes;
    } catch (e) {
      debugPrint('❌ Thumbnail generation failed, using original: $e');
      return originalBytes;
    }
  }

  // ✅ PRE-LOADING METHOD (Updated)
  static Future<void> preloadThumbnails(List<Song> songs) async {
    try {
      debugPrint('🚀 [Preload] Starting thumbnail preload for ${songs.length} songs');
      
      // First 25 songs preload karo
      final songsToPreload = songs.take(25).toList();
      int loadedCount = 0;
      
      for (final song in songsToPreload) {
        getThumbnail(
          songId: song.mediaStoreId,
          songTitle: song.title,
          artist: song.artist,
        ).then((thumbnail) {
          if (thumbnail != null) {
            loadedCount++;
            debugPrint('   ✅ Preloaded: ${song.title} ($loadedCount/${songsToPreload.length})');
          }
        });
        
        // Small delay to prevent overwhelming the system
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      debugPrint('✅ [Preload] Thumbnail preload initiated for $loadedCount songs');
    } catch (e) {
      debugPrint('❌ [Preload] Error: $e');
    }
  }

  // ✅ ENHANCED CACHE MANAGEMENT
  static Future<void> clearCache({bool memoryOnly = false}) async {
    _albumArtCache.clear();
    _thumbnailCache.clear();
    _pendingRequests.clear();
    
    if (!memoryOnly && _isDiskCacheInitialized) {
      try {
        if (await _cacheDir.exists()) {
          await _cacheDir.delete(recursive: true);
          await _cacheDir.create(recursive: true);
          debugPrint('🗑️ Disk cache cleared');
        }
      } catch (e) {
        debugPrint('❌ Error clearing disk cache: $e');
      }
    }
    
    debugPrint('✅ Cache cleared ${memoryOnly ? '(memory only)' : '(memory + disk)'}');
  }
  
  static Future<Map<String, dynamic>> getCacheStats() async {
    int diskThumbCount = 0;
    int diskOriginalCount = 0;
    
    if (_isDiskCacheInitialized && await _cacheDir.exists()) {
      final files = await _cacheDir.list().toList();
      diskThumbCount = files.where((f) => f.path.contains('thumb_')).length;
      diskOriginalCount = files.where((f) => f.path.contains('original_')).length;
    }
    
    return {
      'memory_originals': _albumArtCache.length,
      'memory_thumbnails': _thumbnailCache.length,
      'disk_thumbnails': diskThumbCount,
      'disk_originals': diskOriginalCount,
      'pending_requests': _pendingRequests.length,
      'disk_cache_path': _isDiskCacheInitialized ? _cacheDir.path : 'Not initialized',
    };
  }
  
  static void printCacheStats() async {
    final stats = await getCacheStats();
    debugPrint('📊 [Cache Stats]');
    debugPrint('   Memory - Originals: ${stats['memory_originals']}');
    debugPrint('   Memory - Thumbnails: ${stats['memory_thumbnails']}');
    debugPrint('   Disk - Thumbnails: ${stats['disk_thumbnails']}');
    debugPrint('   Disk - Originals: ${stats['disk_originals']}');
    debugPrint('   Pending Requests: ${stats['pending_requests']}');
    debugPrint('   Disk Path: ${stats['disk_cache_path']}');
  }

  // ✅ EXISTING METHODS (Unchanged)
  static Future<bool> _hasStoragePermission() async {
    try {
      final isAndroid13OrAbove = await _isAndroid13OrAbove();
      final permission = isAndroid13OrAbove ? Permission.audio : Permission.storage;
      
      final status = await permission.status;

      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        final result = await permission.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('❌ Permission check error: $e');
      return false;
    }
  }

  static Future<bool> _isAndroid13OrAbove() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return false;
      }

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      
      return sdkVersion >= 33;
    } catch (e) {
      debugPrint('❌ Error checking Android version: $e');
      return true;
    }
  }

  static String getAlbumArtUri(String? albumArtPath) {
    if (albumArtPath == null || albumArtPath.isEmpty) {
      return '';
    }
    
    if (albumArtPath.startsWith('http')) {
      return albumArtPath;
    } else if (albumArtPath.startsWith('/')) {
      return 'file://$albumArtPath';
    } else {
      return albumArtPath;
    }
  }

  static Future<bool> hasAlbumArt(Song song) async {
    try {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return true;
      }
      
      final art = await getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );
      
      return art != null;
    } catch (e) {
      debugPrint('❌ Error checking album art: $e');
      return false;
    }
  }

  static Future<Uint8List?> getPlaceholderArt() async {
    try {
      final result = await _channel.invokeMethod('getPlaceholderArt');
      
      if (result != null && result is Uint8List) {
        return result;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting placeholder art: $e');
      return null;
    }
  }

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