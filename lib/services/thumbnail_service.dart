import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:i_music/models/song_model.dart';

class ThumbnailService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // ✅ MEMORY CACHE - Fast access ke liye
  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _loadingFutures = {};

  // ✅ DISK CACHE MANAGER
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

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
      print('❌ Error in $method: $e');
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
  }

  // ✅ CHECK IF THUMBNAIL IS CACHED
  static bool isThumbnailCached(int albumId) {
    final cacheKey = 'album_$albumId';
    return _memoryCache.containsKey(cacheKey);
  }
}