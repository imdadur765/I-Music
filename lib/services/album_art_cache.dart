import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class AlbumArtCache {
  static final AlbumArtCache _instance = AlbumArtCache._internal();
  factory AlbumArtCache() => _instance;
  AlbumArtCache._internal();

  static const String _boxName = 'albumArtLifetimeCache';
  late Box<String> _cacheBox;
  bool _isInitialized = false;
  
  // ✅ CONCURRENT OPERATIONS CONTROL
  final Map<String, Future<String?>> _pendingOperations = {};

  Future<void> init() async {
    if (_isInitialized) return;
    
    await Hive.openBox<String>(_boxName);
    _cacheBox = Hive.box<String>(_boxName);
    _isInitialized = true;
    debugPrint('💾 AlbumArtCache initialized - LIFETIME CACHING READY');
  }

  // ✅ ASYNC CACHE CHECK - NO MAIN THREAD BLOCKING
  Future<String?> getCachedAlbumArt(String cacheKey, String originalPath) async {
    if (!_isInitialized) await init();
    
    // ✅ PREVENT DUPLICATE REQUESTS FOR SAME KEY
    if (_pendingOperations.containsKey(cacheKey)) {
      return _pendingOperations[cacheKey];
    }

    final operation = _getOrCreateCache(cacheKey, originalPath);
    _pendingOperations[cacheKey] = operation;
    
    // Clean up when complete
    operation.whenComplete(() => _pendingOperations.remove(cacheKey));
    
    return operation;
  }

  Future<String?> _getOrCreateCache(String cacheKey, String originalPath) async {
    try {
      // ✅ 1. ASYNC CACHE CHECK
      if (_cacheBox.containsKey(cacheKey)) {
        final cachedPath = _cacheBox.get(cacheKey);
        if (cachedPath != null && await File(cachedPath).exists()) { // ✅ ASYNC CHECK
          debugPrint('💾 LIFETIME CACHE HIT: $cacheKey');
          return cachedPath;
        } else {
          await _cacheBox.delete(cacheKey);
        }
      }

      // ✅ 2. CREATE CACHE IN BACKGROUND
      debugPrint('🔄 LIFETIME CACHE MISS - Caching: $cacheKey');
      return await _createLifetimeCache(cacheKey, originalPath);
    } catch (e) {
      debugPrint('❌ Error in _getOrCreateCache: $e');
      return null;
    }
  }

  Future<String?> _createLifetimeCache(String cacheKey, String originalPath) async {
    try {
      if (originalPath.isEmpty) return null;
      
      final originalFile = File(originalPath);
      if (await originalFile.exists()) {
        final cacheDir = await getTemporaryDirectory();
        final cachedFile = File('${cacheDir.path}/lifetime_${cacheKey.hashCode}.jpg');
        
        // ✅ ASYNC FILE OPERATIONS
        await originalFile.copy(cachedFile.path);
        await _cacheBox.put(cacheKey, cachedFile.path);
        
        debugPrint('💾 LIFETIME CACHE CREATED: $cacheKey');
        return cachedFile.path;
      }
    } catch (e) {
      debugPrint('❌ Error creating lifetime cache: $e');
    }
    return null;
  }

  // ✅ ASYNC CACHE CHECK
  Future<bool> isCachedAsync(String cacheKey) async {
    if (!_isInitialized) return false;
    return _cacheBox.containsKey(cacheKey);
  }

  // ✅ NON-BLOCKING PRELOADING
  Future<void> preloadAllAlbums(List<Map<String, dynamic>> songs) async {
    if (!_isInitialized) await init();
    
    debugPrint('🚀 LIFETIME PRELOAD: Starting for ${songs.length} songs...');
    
    // ✅ USE ISOLATES OR COMPUTE FOR HEAVY WORK
    final preloadFutures = <Future>[];
    int batchSize = 10; // Process in batches
    
    for (int i = 0; i < songs.length; i += batchSize) {
      final batch = songs.sublist(i, i + batchSize > songs.length ? songs.length : i + batchSize);
      
      final batchFuture = Future(() async {
        for (final song in batch) {
          final albumId = song['album']?.toString() ?? 'unknown_${song['id']}';
          final albumArtPath = song['albumArt']?.toString() ?? '';
          
          if (albumArtPath.isNotEmpty) {
            // Don't await - let them run concurrently
            getCachedAlbumArt(albumId, albumArtPath);
          }
        }
      });
      
      preloadFutures.add(batchFuture);
      
      // Small delay between batches to prevent UI freeze
      if (i + batchSize < songs.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    
    await Future.wait(preloadFutures);
    debugPrint('💾 LIFETIME PRELOAD COMPLETE');
  }

  // ✅ QUICK PRELOAD FOR VISIBLE ITEMS ONLY
  Future<void> preloadVisibleAlbums(List<Map<String, dynamic>> visibleSongs) async {
    if (!_isInitialized) await init();
    
    final futures = <Future>[];
    
    for (final song in visibleSongs) {
      final albumId = song['album']?.toString() ?? 'unknown_${song['id']}';
      final albumArtPath = song['albumArt']?.toString() ?? '';
      
      if (albumArtPath.isNotEmpty) {
        futures.add(getCachedAlbumArt(albumId, albumArtPath));
      }
    }
    
    await Future.wait(futures, eagerError: false);
  }

  // ✅ Clear cache (optional)
  Future<void> clearCache() async {
    if (!_isInitialized) return;
    
    final cacheDir = await getTemporaryDirectory();
    final cacheFiles = await cacheDir.list().toList();
    
    final deleteFutures = <Future>[];
    for (var file in cacheFiles) {
      if (file.path.contains('lifetime_')) {
        deleteFutures.add(file.delete());
      }
    }
    
    await Future.wait(deleteFutures);
    await _cacheBox.clear();
    debugPrint('🗑️ Lifetime album art cache cleared');
  }

  // ✅ Get cache stats
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized) return {'status': 'Not initialized'};
    
    int diskCacheCount = 0;
    final cacheDir = await getTemporaryDirectory();
    final cacheFiles = await cacheDir.list().toList();
    
    for (var file in cacheFiles) {
      if (file.path.contains('lifetime_')) {
        diskCacheCount++;
      }
    }
    
    return {
      'hive_entries': _cacheBox.length,
      'disk_files': diskCacheCount,
      'status': 'Active',
      'pending_operations': _pendingOperations.length
    };
  }
}