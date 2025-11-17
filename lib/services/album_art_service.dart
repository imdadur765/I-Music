import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:i_music/models/song_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AlbumArtService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');

  // ✅ MEMORY CACHE - FAST ACCESS
  static final Map<int, Uint8List> _albumArtCache = {};
  static final Map<int, Uint8List> _thumbnailCache = {};
  static final Set<int> _pendingRequests = {};

  // ✅ LIFETIME CACHE - PERSISTENT STORAGE
  static late Box<String> _lifetimeCacheBox;
  static bool _isLifetimeCacheInitialized = false;
  
  // ✅ PERFORMANCE OPTIMIZATIONS
  static final Map<String, Future<Uint8List?>> _pendingCacheOperations = {};
  static int _concurrentOperations = 0;
  static const int _maxConcurrentOperations = 3;

  // ✅ INITIALIZATION
  static Future<void> init() async {
    if (_isLifetimeCacheInitialized) return;
    
    try {
      await Hive.openBox<String>('albumArtLifetimeCache');
      _lifetimeCacheBox = Hive.box<String>('albumArtLifetimeCache');
      _isLifetimeCacheInitialized = true;
      
      debugPrint('💾 LIFETIME CACHE INITIALIZED: ${_lifetimeCacheBox.length} entries');
    } catch (e) {
      debugPrint('❌ Error initializing lifetime cache: $e');
    }
  }

  // ✅ MAIN ALBUM ART GETTER - FULLY OPTIMIZED
  static Future<Uint8List?> getAlbumArt({
    required int songId,
    required String songTitle,
    required String artist,
    bool preload = false,
  }) async {
    // ✅ 1. MEMORY CACHE CHECK (INSTANT)
    if (_albumArtCache.containsKey(songId)) {
      return _albumArtCache[songId];
    }

    // ✅ 2. DEDUPLICATE SIMULTANEOUS REQUESTS
    final cacheKey = songId.toString();
    if (_pendingCacheOperations.containsKey(cacheKey)) {
      return _pendingCacheOperations[cacheKey];
    }

    final operation = _getAlbumArtInternal(
      songId: songId,
      songTitle: songTitle,
      artist: artist,
      preload: preload,
    );
    
    _pendingCacheOperations[cacheKey] = operation;
    operation.whenComplete(() => _pendingCacheOperations.remove(cacheKey));
    
    return operation;
  }

  // ✅ INTERNAL IMPLEMENTATION
  static Future<Uint8List?> _getAlbumArtInternal({
    required int songId,
    required String songTitle,
    required String artist,
    bool preload = false,
  }) async {
    try {
      // ✅ 1. LIFETIME CACHE CHECK (PERSISTENT)
      final lifetimeCached = await _loadFromLifetimeCache(songId);
      if (lifetimeCached != null) {
        _albumArtCache[songId] = lifetimeCached;
        return lifetimeCached;
      }

      // ✅ 2. PREVENT DUPLICATE NATIVE REQUESTS
      if (_pendingRequests.contains(songId)) {
        await _waitForPendingRequest(songId);
        if (_albumArtCache.containsKey(songId)) {
          return _albumArtCache[songId];
        }
      }

      _pendingRequests.add(songId);

      // ✅ 3. CONCURRENCY CONTROL - DON'T OVERLOAD SYSTEM
      while (_concurrentOperations >= _maxConcurrentOperations) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
      _concurrentOperations++;

      // ✅ 4. NATIVE CHANNEL CALL WITH TIMEOUT
      final result = await _channel.invokeMethod('getAlbumArt', {
        'songId': songId,
        'title': songTitle,
        'artist': artist,
      }).timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('⏰ TIMEOUT: Album art request for $songId');
        return null;
      });

      if (result != null && result is Uint8List && result.isNotEmpty) {
        // ✅ 5. ASYNC CACHE SAVE (DON'T AWAIT)
        _albumArtCache[songId] = result;
        unawaited(_saveToLifetimeCache(songId, result));

        if (!preload) {
          debugPrint('✅ LOADED: "$songTitle" (${result.length} bytes)');
        }
        return result;
      } else {
        if (!preload) {
          debugPrint('❌ NO DATA: "$songTitle"');
        }
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ PLATFORM ERROR: $songTitle - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ UNKNOWN ERROR: $songTitle - $e');
      return null;
    } finally {
      _pendingRequests.remove(songId);
      _concurrentOperations--;
    }
  }

  // ✅ WAIT FOR PENDING REQUEST COMPLETION
  static Future<void> _waitForPendingRequest(int songId) async {
    int attempts = 0;
    while (_pendingRequests.contains(songId) && attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 5));
      attempts++;
    }
  }

  // ✅ LIFETIME CACHE - SAVE (ASYNC)
  static Future<void> _saveToLifetimeCache(int songId, Uint8List data) async {
    if (!_isLifetimeCacheInitialized || data.isEmpty) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/lifetime_$songId.jpg');
      await file.writeAsBytes(data);
      await _lifetimeCacheBox.put(songId, file.path);
    } catch (e) {
      debugPrint('❌ Cache save error: $e');
    }
  }

  // ✅ LIFETIME CACHE - LOAD (ASYNC)
  static Future<Uint8List?> _loadFromLifetimeCache(int songId) async {
    if (!_isLifetimeCacheInitialized) return null;

    try {
      final filePath = _lifetimeCacheBox.get(songId);
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final data = await file.readAsBytes();
          return data;
        } else {
          // File missing, cleanup
          await _lifetimeCacheBox.delete(songId);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Cache load error: $e');
      return null;
    }
  }

  // ✅ SMART PRELOAD - FOR VISIBLE ITEMS ONLY
  static Future<void> preloadVisibleAlbumArts(List<Map<String, dynamic>> visibleSongs) async {
    if (!_isLifetimeCacheInitialized) await init();
    if (visibleSongs.isEmpty) return;

    debugPrint('🚀 PRELOADING ${visibleSongs.length} visible songs...');
    
    final futures = <Future>[];
    const batchSize = 6;

    for (int i = 0; i < visibleSongs.length; i += batchSize) {
      final endIndex = i + batchSize > visibleSongs.length ? visibleSongs.length : i + batchSize;
      final batch = visibleSongs.sublist(i, endIndex);

      final batchFuture = Future(() async {
        for (final song in batch) {
          final songId = song['id'] ?? song['mediaStoreId'];
          final title = song['title']?.toString() ?? '';
          final artist = song['artist']?.toString() ?? '';
          
          if (songId != null && title.isNotEmpty) {
            // Don't await - fire and forget
            unawaited(getAlbumArt(
              songId: songId,
              songTitle: title,
              artist: artist,
              preload: true,
            ));
          }
        }
      });

      futures.add(batchFuture);
      
      // Yield to UI thread between batches
      if (endIndex < visibleSongs.length) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    await Future.wait(futures);
  }

  // ✅ BACKGROUND PRELOAD - ENTIRE LIBRARY
  static Future<void> preloadAllAlbumArts(List<Map<String, dynamic>> allSongs) async {
    if (!_isLifetimeCacheInitialized) await init();
    if (allSongs.isEmpty) return;

    debugPrint('🚀 BACKGROUND PRELOAD: ${allSongs.length} songs...');
    
    // Run in background without blocking
    unawaited(Future(() async {
      int processed = 0;
      const batchSize = 15;
      
      for (int i = 0; i < allSongs.length; i += batchSize) {
        final endIndex = i + batchSize > allSongs.length ? allSongs.length : i + batchSize;
        final batch = allSongs.sublist(i, endIndex);

        for (final song in batch) {
          final songId = song['id'] ?? song['mediaStoreId'];
          final albumArtPath = song['albumArt']?.toString() ?? '';
          
          if (songId != null && albumArtPath.isNotEmpty) {
            // Only cache if not already cached
            final existingPath = _lifetimeCacheBox.get(songId);
            if (existingPath == null) {
              try {
                final file = File(albumArtPath);
                if (await file.exists()) {
                  final bytes = await file.readAsBytes();
                  await _saveToLifetimeCache(songId, bytes);
                }
              } catch (e) {
                // Silent fail for background preload
              }
            }
          }
        }
        
        processed += batch.length;
        
        // Progress update every 100 songs
        if (processed % 100 == 0) {
          debugPrint('📊 PRELOAD PROGRESS: $processed/${allSongs.length}');
        }
        
        // Important: Yield to UI thread
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      debugPrint('💾 BACKGROUND PRELOAD COMPLETE: $processed songs');
    }));
  }

  // ✅ OPTIMIZED THUMBNAIL GETTER
  static Future<Uint8List?> getThumbnail({
    required int songId,
    required String songTitle,
    required String artist,
  }) async {
    try {
      // Memory cache check
      if (_thumbnailCache.containsKey(songId)) {
        return _thumbnailCache[songId];
      }

      // Get original image
      final original = await getAlbumArt(
        songId: songId,
        songTitle: songTitle,
        artist: artist,
      );

      if (original != null) {
        // Generate thumbnail (replace with your implementation)
        final thumbnail = await _generateThumbnail(original);
        _thumbnailCache[songId] = thumbnail;
        return thumbnail;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ THUMBNAIL GENERATOR
  static Future<Uint8List> _generateThumbnail(Uint8List originalBytes) async {
    // TODO: Implement your thumbnail generation logic
    // For now, return original as placeholder
    return originalBytes;
  }

  // ✅ PERMISSION CHECK
  static Future<bool> _hasStoragePermission() async {
    try {
      // TODO: Implement your permission check logic
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ CACHE MANAGEMENT
  static Future<void> clearCache({bool memoryOnly = false}) async {
    // Clear memory caches
    _albumArtCache.clear();
    _thumbnailCache.clear();
    _pendingRequests.clear();
    _pendingCacheOperations.clear();

    if (!memoryOnly && _isLifetimeCacheInitialized) {
      try {
        // Clear Hive entries
        await _lifetimeCacheBox.clear();
        
        // Delete cached files
        final tempDir = await getTemporaryDirectory();
        final files = await tempDir.list().toList();
        
        final deleteFutures = files
            .where((file) => file.path.contains('lifetime_'))
            .map((file) => file.delete());
            
        await Future.wait(deleteFutures, eagerError: false);
        
        debugPrint('🗑️ LIFETIME CACHE CLEARED');
      } catch (e) {
        debugPrint('❌ Error clearing lifetime cache: $e');
      }
    }

    debugPrint('✅ CACHE CLEARED: ${memoryOnly ? 'memory only' : 'complete'}');
  }

  // ✅ CHECK IF ALBUM ART EXISTS
  static Future<bool> hasAlbumArt(Song song) async {
    try {
      if (_albumArtCache.containsKey(song.id)) return true;
      
      if (_isLifetimeCacheInitialized) {
        final filePath = _lifetimeCacheBox.get(song.id);
        if (filePath != null && await File(filePath).exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ GET ALBUM ART URI
  static String getAlbumArtUri(String? albumArtPath) {
    return albumArtPath ?? '';
  }

  // ✅ CACHE STATISTICS
  static Future<Map<String, dynamic>> getCacheStats() async {
    int diskFileCount = 0;

    if (_isLifetimeCacheInitialized) {
      try {
        final tempDir = await getTemporaryDirectory();
        final files = await tempDir.list().toList();
        diskFileCount = files.where((f) => f.path.contains('lifetime_')).length;
      } catch (e) {
        debugPrint('❌ Error counting disk files: $e');
      }
    }

    return {
      'memory_originals': _albumArtCache.length,
      'memory_thumbnails': _thumbnailCache.length,
      'lifetime_entries': _isLifetimeCacheInitialized ? _lifetimeCacheBox.length : 0,
      'disk_files': diskFileCount,
      'pending_requests': _pendingRequests.length,
      'pending_operations': _pendingCacheOperations.length,
      'concurrent_operations': _concurrentOperations,
    };
  }

  // ✅ PRINT CACHE STATS
  static void printCacheStats() async {
    final stats = await getCacheStats();
    debugPrint('📊 ALBUM ART CACHE STATS:');
    debugPrint('   Memory Originals: ${stats['memory_originals']}');
    debugPrint('   Memory Thumbnails: ${stats['memory_thumbnails']}');
    debugPrint('   Lifetime Entries: ${stats['lifetime_entries']}');
    debugPrint('   Disk Files: ${stats['disk_files']}');
    debugPrint('   Pending Requests: ${stats['pending_requests']}');
    debugPrint('   Pending Operations: ${stats['pending_operations']}');
    debugPrint('   Concurrent Operations: ${stats['concurrent_operations']}');
  }

  // ✅ CHECK IF CACHE IS INITIALIZED
  static bool get isInitialized => _isLifetimeCacheInitialized;

  // ✅ GET CACHE SIZE INFO
  static Future<int> getCacheSize() async {
    if (!_isLifetimeCacheInitialized) return 0;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();
      
      int totalSize = 0;
      for (var file in files.where((f) => f.path.contains('lifetime_'))) {
        final stat = await file.stat();
        totalSize += stat.size;
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}