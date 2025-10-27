// lib/services/thumbnail_service.dart - ENHANCED VERSION
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:i_music/models/song_model.dart';

class ThumbnailService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // ✅ MEMORY CACHE - Fast access ke liye
  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _loadingFutures = {};
  static final Map<String, String> _tempFilePaths = {}; // ✅ ADDED: For system notifications

  // ✅ DISK CACHE MANAGER
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  // ✅ TEMP DIRECTORY FOR SYSTEM NOTIFICATIONS
  static const String _tempDirName = 'album_art_cache';

  // ✅ PRELOAD THUMBNAILS ON APP START
  static Future<void> preloadThumbnails(List<int> albumIds) async {
    final futures = <Future>[];
    for (final albumId in albumIds) {
      if (albumId > 0) {
        futures.add(getAlbumArtBytes(albumId));
      }
    }
    await Future.wait(futures, eagerError: false);
  }

  // ✅ GET ALBUM ART WITH CACHING
  static Future<Uint8List?> getAlbumArtBytes(int albumId) async {
    if (albumId <= 0) return null;
    
    final cacheKey = 'album_$albumId';
    
    // ✅ 1. CHECK MEMORY CACHE (FASTEST - 1ms)
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }
    
    // ✅ 2. CHECK IF ALREADY LOADING
    if (_loadingFutures.containsKey(cacheKey)) {
      return _loadingFutures[cacheKey];
    }
    
    // ✅ 3. CHECK DISK CACHE
    final file = await _cacheManager.getFileFromCache(cacheKey);
    if (file != null && file.file != null) {
      final bytes = await file.file!.readAsBytes();
      if (bytes.isNotEmpty) {
        _memoryCache[cacheKey] = bytes; // Memory cache mein store karen
        return bytes;
      }
    }

    // ✅ 4. LOAD FROM NATIVE AND CACHE
    final future = _fetchFromNative(cacheKey, 'getAlbumArtBytes', {'albumId': albumId});
    _loadingFutures[cacheKey] = future;
    
    final result = await future;
    _loadingFutures.remove(cacheKey);
    
    return result;
  }

  // ✅ GET SONG THUMBNAIL WITH CACHING
  static Future<Uint8List?> getSongThumbnail(int songId) async {
    if (songId <= 0) return null;
    
    final cacheKey = 'song_$songId';
    
    // ✅ Memory Cache check
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }
    
    if (_loadingFutures.containsKey(cacheKey)) {
      return _loadingFutures[cacheKey];
    }
    
    // ✅ Disk Cache check
    final file = await _cacheManager.getFileFromCache(cacheKey);
    if (file != null && file.file != null) {
      final bytes = await file.file!.readAsBytes();
      if (bytes.isNotEmpty) {
        _memoryCache[cacheKey] = bytes;
        return bytes;
      }
    }

    final future = _fetchFromNative(cacheKey, 'getSongThumbnail', {'songId': songId});
    _loadingFutures[cacheKey] = future;
    
    final result = await future;
    _loadingFutures.remove(cacheKey);
    
    return result;
  }

  // ✅ NEW: GET ARTWORK URI FOR SYSTEM NOTIFICATIONS
  static Future<Uri?> getArtworkUri(String songId, Uint8List? artworkData) async {
    if (artworkData == null || artworkData.isEmpty) return null;

    try {
      // ✅ Check memory cache first
      if (_memoryCache.containsKey(songId)) {
        final cachedPath = _tempFilePaths[songId];
        if (cachedPath != null && await File(cachedPath).exists()) {
          return Uri.file(cachedPath);
        }
      }

      // ✅ Create temporary file for system notifications
      final tempPath = await _getTempFilePath(songId);
      if (tempPath != null) {
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(artworkData);
        _memoryCache[songId] = artworkData;
        _tempFilePaths[songId] = tempPath;
        return Uri.file(tempPath);
      }
    } catch (e) {
      debugPrint('⚠️ Error creating artwork file: $e');
    }
    return null;
  }

  // ✅ NEW: GET CACHED ARTWORK BY SONG ID
  static Uint8List? getCachedArtwork(String songId) {
    return _memoryCache[songId];
  }

  // ✅ NEW: CACHE ARTWORK IN MEMORY
  static void cacheArtwork(String songId, Uint8List artworkData) {
    _memoryCache[songId] = artworkData;
  }

  // ✅ HELPER: GET TEMPORARY FILE PATH
  static Future<String?> _getTempFilePath(String key) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$_tempDirName');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final hash = key.hashCode.toUnsigned(0x7FFFFFFF);
      return '${cacheDir.path}/artwork_$hash.jpg';
    } catch (e) {
      debugPrint('❌ Error getting temp path: $e');
      return null;
    }
  }

  // ✅ FETCH FROM NATIVE AND CACHE
  static Future<Uint8List?> _fetchFromNative(String cacheKey, String method, Map<String, dynamic> arguments) async {
    try {
      final result = await _channel.invokeMethod(method, arguments);
      
      if (result != null && (result as Uint8List).isNotEmpty) {
        // ✅ STORE IN MEMORY CACHE
        _memoryCache[cacheKey] = result;
        
        // ✅ STORE IN DISK CACHE
        await _cacheManager.putFile(cacheKey, result);
        
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error in $method: $e');
      return null;
    }
  }

  // ✅ SONG OBJECT SE OPTIMIZED FETCH
  static Future<Uint8List?> getThumbnailForSong(Song song) async {
    // ✅ Pehle songId se try karen
    final songId = int.tryParse(song.id);
    if (songId != null) {
      final thumbnail = await getSongThumbnail(songId);
      if (thumbnail != null) return thumbnail;
    }
    
    // ✅ Fir albumId se try karen
    if (song.albumId > 0) {
      return await getAlbumArtBytes(song.albumId);
    }
    
    return null;
  }

  // ✅ CLEAR CACHE (if needed)
  static void clearMemoryCache() {
    _memoryCache.clear();
    _loadingFutures.clear();
    _tempFilePaths.clear();
  }

  // ✅ CLEAN UP TEMP FILES
  static Future<void> cleanTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$_tempDirName');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _tempFilePaths.clear();
    } catch (e) {
      debugPrint('❌ Error cleaning temp files: $e');
    }
  }

  // ✅ CHECK IF THUMBNAIL IS CACHED
  static bool isThumbnailCached(int albumId) {
    final cacheKey = 'album_$albumId';
    return _memoryCache.containsKey(cacheKey);
  }
}