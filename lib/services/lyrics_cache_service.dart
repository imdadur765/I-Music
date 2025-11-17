import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LyricsCacheService {
  static late Box<String> _lyricsCache;
  static late Box<String> _appDataCache;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Initialize lyrics cache
      if (!Hive.isBoxOpen('lyrics_cache')) {
        _lyricsCache = await Hive.openBox<String>('lyrics_cache');
      } else {
        _lyricsCache = Hive.box<String>('lyrics_cache');
      }
      
      // Initialize app data cache
      if (!Hive.isBoxOpen('app_data_cache')) {
        _appDataCache = await Hive.openBox<String>('app_data_cache');
      } else {
        _appDataCache = Hive.box<String>('app_data_cache');
      }
      
      _isInitialized = true;
      if (kDebugMode) {
        print('Lyrics Cache Service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Lyrics Cache Service initialization error: $e');
      }
      // Continue without cache if initialization fails
    }
  }

  // ✅ Helper method to create consistent cache keys
  static String _createCacheKey(String songTitle, String artist) {
    return '${songTitle.trim().toLowerCase()}_${artist.trim().toLowerCase()}'
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  // ✅ MANUAL LYRICS CACHING - SYNC VERSION
  static String? getCachedLyrics(String songTitle, String artist) {
    if (!_isInitialized) return null;
    
    final key = _createCacheKey(songTitle, artist);
    final cached = _lyricsCache.get(key);
    
    if (cached != null && kDebugMode) {
      print('Lyrics cache hit for: $key');
    }
    
    return cached;
  }
  
  // ✅ MANUAL LYRICS CACHING - ASYNC VERSION
  static Future<String?> getCachedLyricsAsync(String songTitle, String artist) async {
    if (!_isInitialized) return null;
    
    final key = _createCacheKey(songTitle, artist);
    final cached = _lyricsCache.get(key);
    
    if (cached != null && kDebugMode) {
      print('Lyrics cache hit for: $key');
    }
    
    return cached;
  }

  // ✅ CACHE MANUAL LYRICS
  static Future<void> cacheLyrics(String songTitle, String artist, String lyrics) async {
    if (!_isInitialized) return;
    
    final key = _createCacheKey(songTitle, artist);
    await _lyricsCache.put(key, lyrics);
    
    if (kDebugMode) {
      print('Manual lyrics cached: $key');
    }
  }

  // ✅ APP DATA CACHING (For future API integration)
  static Future<void> cacheAppData(String key, String data) async {
    if (!_isInitialized) return;
    await _appDataCache.put(key, data);
  }

  static String? getCachedAppData(String key) {
    if (!_isInitialized) return null;
    return _appDataCache.get(key);
  }

  // ✅ CLEAR CACHE METHODS
  static Future<void> clearLyricsCache() async {
    if (!_isInitialized) return;
    await _lyricsCache.clear();
    if (kDebugMode) {
      print('Lyrics cache cleared');
    }
  }

  static Future<void> clearAppDataCache() async {
    if (!_isInitialized) return;
    await _appDataCache.clear();
    if (kDebugMode) {
      print('App data cache cleared');
    }
  }

  static Future<void> clearAllCache() async {
    if (!_isInitialized) return;
    await _lyricsCache.clear();
    await _appDataCache.clear();
    if (kDebugMode) {
      print('All cache cleared');
    }
  }

  // ✅ CACHE STATISTICS
  static Map<String, int> getCacheStats() {
    if (!_isInitialized) return {'lyrics': 0, 'app_data': 0};
    
    return {
      'lyrics': _lyricsCache.length,
      'app_data': _appDataCache.length,
    };
  }

  // ✅ CHECK IF LYRIC EXISTS IN CACHE
  static bool hasCachedLyrics(String songTitle, String artist) {
    if (!_isInitialized) return false;
    
    final key = _createCacheKey(songTitle, artist);
    return _lyricsCache.containsKey(key);
  }

  // ✅ GET ALL CACHED LYRIC KEYS (For management UI)
  static List<String> getAllCachedLyricKeys() {
    if (!_isInitialized) return [];
    return _lyricsCache.keys.cast<String>().toList();
  }

  // ✅ REMOVE SPECIFIC LYRIC FROM CACHE
  static Future<void> removeCachedLyrics(String songTitle, String artist) async {
    if (!_isInitialized) return;
    
    final key = _createCacheKey(songTitle, artist);
    await _lyricsCache.delete(key);
    
    if (kDebugMode) {
      print('Removed cached lyrics: $key');
    }
  }
}