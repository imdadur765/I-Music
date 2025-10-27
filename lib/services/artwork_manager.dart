// lib/services/artwork_manager.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ArtworkManager {
  static final ArtworkManager _instance = ArtworkManager._internal();
  factory ArtworkManager() => _instance;
  ArtworkManager._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, String> _tempFilePaths = {};
  static const String _tempDirName = 'album_art_cache';

  Future<String?> _getTempFilePath(String key) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$_tempDirName');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final hash = key.hashCode.toUnsigned(0x7FFFFFFF);
      return '${cacheDir.path}/artwork_$hash.jpg';
    } catch (e) {
      print('Error getting temp path: $e');
      return null;
    }
  }

  Future<Uri?> getArtworkUri(String songId, Uint8List? artworkData) async {
    if (artworkData == null || artworkData.isEmpty) return null;

    try {
      // Memory cache check
      if (_memoryCache.containsKey(songId)) {
        final cachedPath = _tempFilePaths[songId];
        if (cachedPath != null && await File(cachedPath).exists()) {
          return Uri.file(cachedPath);
        }
      }

      // Create new temp file
      final tempPath = await _getTempFilePath(songId);
      if (tempPath != null) {
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(artworkData);
        _memoryCache[songId] = artworkData;
        _tempFilePaths[songId] = tempPath;
        return Uri.file(tempPath);
      }
    } catch (e) {
      print('Error creating artwork file: $e');
    }
    return null;
  }

  Uint8List? getCachedArtwork(String songId) {
    return _memoryCache[songId];
  }

  void cacheArtwork(String songId, Uint8List artworkData) {
    _memoryCache[songId] = artworkData;
  }

  void clearCache() {
    _memoryCache.clear();
    _tempFilePaths.clear();
  }
}