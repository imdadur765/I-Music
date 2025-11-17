// lib/services/preload_service.dart
import 'dart:typed_data';
import 'package:i_music/services/album_art_service.dart';
import 'package:i_music/models/song_model.dart';
import 'package:flutter/foundation.dart';

class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();

  final Map<int, Uint8List?> _thumbnailCache = {};
  final Set<int> _preloadedIds = {};
  bool _isPreloading = false;

  // ✅ PRELOAD ALL THUMBNAILS AT APP START
  Future<void> preloadAllThumbnails(List<Song> songs) async {
    if (_isPreloading || songs.isEmpty) return;
    
    _isPreloading = true;
    
    try {
      debugPrint('🚀 PRELOAD: Starting thumbnail preloading for ${songs.length} songs');
      
      // ✅ BATCH PROCESSING - Load in chunks of 20
      for (int i = 0; i < songs.length; i += 20) {
        final end = (i + 20) < songs.length ? (i + 20) : songs.length;
        final batch = songs.sublist(i, end);
        
        await _preloadBatch(batch);
        
        // ✅ Small delay to prevent UI freeze
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      debugPrint('✅ PRELOAD: Completed preloading ${_thumbnailCache.length} thumbnails');
    } catch (e) {
      debugPrint('❌ PRELOAD ERROR: $e');
    } finally {
      _isPreloading = false;
    }
  }

  Future<void> _preloadBatch(List<Song> batch) async {
    final futures = <Future<void>>[];
    
    for (final song in batch) {
      if (_preloadedIds.contains(song.mediaStoreId)) continue;
      
      futures.add(_loadAndCacheThumbnail(song));
    }
    
    await Future.wait(futures, eagerError: false);
  }

  Future<void> _loadAndCacheThumbnail(Song song) async {
    try {
      final thumbnail = await AlbumArtService.getThumbnail(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );
      
      _thumbnailCache[song.mediaStoreId] = thumbnail;
      _preloadedIds.add(song.mediaStoreId);
    } catch (e) {
      _thumbnailCache[song.mediaStoreId] = null;
      _preloadedIds.add(song.mediaStoreId);
    }
  }

  Uint8List? getThumbnail(int mediaStoreId) {
    return _thumbnailCache[mediaStoreId];
  }

  bool isThumbnailPreloaded(int mediaStoreId) {
    return _preloadedIds.contains(mediaStoreId);
  }

  void clearCache() {
    _thumbnailCache.clear();
    _preloadedIds.clear();
    _isPreloading = false;
  }

  static Future<void> init() async {}
}