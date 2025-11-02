// lib/services/disk_cache_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DiskCacheService {
  static final DiskCacheService _instance = DiskCacheService._internal();
  factory DiskCacheService() => _instance;
  DiskCacheService._internal();

  static const String _thumbnailDir = 'thumbnails';
  static const String _originalDir = 'originals';
  late Directory _cacheDir;

  // ✅ INITIALIZE CACHE
  Future<void> init() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDocDir.path}/album_art_cache');
      
      // Create cache directories if they don't exist
      await _cacheDir.create(recursive: true);
      await Directory('${_cacheDir.path}/$_thumbnailDir').create(recursive: true);
      await Directory('${_cacheDir.path}/$_originalDir').create(recursive: true);
      
      debugPrint('✅ Disk cache initialized: ${_cacheDir.path}');
    } catch (e) {
      debugPrint('❌ Error initializing disk cache: $e');
    }
  }

  // ✅ SAVE TO DISK CACHE
  Future<void> saveToCache(int songId, Uint8List data, {bool isThumbnail = true}) async {
    try {
      final dir = isThumbnail ? _thumbnailDir : _originalDir;
      final file = File('${_cacheDir.path}/$dir/$songId.jpg');
      await file.writeAsBytes(data);
      debugPrint('💾 Saved to disk cache: ${file.path}');
    } catch (e) {
      debugPrint('❌ Error saving to disk cache: $e');
    }
  }

  // ✅ LOAD FROM DISK CACHE
  Future<Uint8List?> loadFromCache(int songId, {bool isThumbnail = true}) async {
    try {
      final dir = isThumbnail ? _thumbnailDir : _originalDir;
      final file = File('${_cacheDir.path}/$dir/$songId.jpg');
      
      if (await file.exists()) {
        final data = await file.readAsBytes();
        debugPrint('📂 Loaded from disk cache: ${file.path} (${data.length} bytes)');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading from disk cache: $e');
      return null;
    }
  }

  // ✅ CHECK IF EXISTS IN CACHE
  Future<bool> existsInCache(int songId, {bool isThumbnail = true}) async {
    try {
      final dir = isThumbnail ? _thumbnailDir : _originalDir;
      final file = File('${_cacheDir.path}/$dir/$songId.jpg');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // ✅ CLEAR CACHE (Optional)
  Future<void> clearCache() async {
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

  // ✅ GET CACHE SIZE INFO
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final thumbnailDir = Directory('${_cacheDir.path}/$_thumbnailDir');
      final originalDir = Directory('${_cacheDir.path}/$_originalDir');
      
      int thumbnailCount = 0;
      int originalCount = 0;
      
      if (await thumbnailDir.exists()) {
        thumbnailCount = (await thumbnailDir.list().toList()).whereType<File>().length;
      }
      
      if (await originalDir.exists()) {
        originalCount = (await originalDir.list().toList()).whereType<File>().length;
      }
      
      return {
        'thumbnailCount': thumbnailCount,
        'originalCount': originalCount,
        'totalCount': thumbnailCount + originalCount,
        'cachePath': _cacheDir.path,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}