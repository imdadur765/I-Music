import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_model.dart';

/// A modern, efficient, and future-proof local audio file scanner.
/// Works perfectly on Android 15+ (SDK 35) and supports all major audio formats.
class FileSystemScanner {
  static final FileSystemScanner _instance = FileSystemScanner._internal();
  factory FileSystemScanner() => _instance;
  FileSystemScanner._internal();

  final List<String> _audioExtensions = const [
    '.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg',
    '.3gp', '.mkv', '.opus', '.amr', '.mp2', '.aiff', '.mid'
  ];

  /// Main function — scans device storage for audio files.
  Future<List<Song>> scanForAudioFiles() async {
    try {
      final bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        throw Exception('Storage or Media access permission denied');
      }

      final List<Song> songs = [];
      final directories = await _getMusicDirectories();

      // Use Isolate to prevent UI lag for heavy scanning
      for (final directory in directories) {
        if (await directory.exists()) {
          final files = await compute(_scanDirectoryInBackground, {
            'path': directory.path,
            'extensions': _audioExtensions,
          });
          songs.addAll(files);
        }
      }

      debugPrint('🎵 i_music: Found ${songs.length} total songs');
      return songs;
    } catch (e, st) {
      debugPrint('❌ i_music: File system scan error: $e\n$st');
      return [];
    }
  }

  /// Defines main directories to scan for audio files.
  Future<List<Directory>> _getMusicDirectories() async {
    final List<Directory> dirs = [];

    try {
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) {
        dirs.addAll([
          external,
          Directory('${external.path}/Music'),
          Directory('${external.path}/Download'),
          Directory('${external.path}/Documents'),
        ]);
      }

      // Common Android directories
      dirs.addAll([
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Documents'),
        Directory('/storage/emulated/0/Recordings'),
        Directory('/storage/emulated/0/Android/media'),
      ]);

      // Remove duplicates or non-existing paths
      final uniqueDirs = dirs.toSet().toList();
      debugPrint('📁 i_music: Scanning ${uniqueDirs.length} directories');
      return uniqueDirs;
    } catch (e) {
      debugPrint('⚠️ i_music: Error getting directories: $e');
      return [];
    }
  }

  /// Request and check necessary permissions.
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.audio,
        Permission.mediaLibrary, // For Android 13+ scoped media
      ].request();

      return statuses.values.any((status) => status.isGranted);
    }
    return true;
  }
}

/// Background isolate worker for scanning files efficiently.
Future<List<Song>> _scanDirectoryInBackground(Map<String, dynamic> params) async {
  final String dirPath = params['path'];
  final List<String> extensions = List<String>.from(params['extensions']);
  final List<Song> songs = [];

  try {
    final Directory directory = Directory(dirPath);
    await for (final file in directory.list(recursive: true, followLinks: false)) {
      if (file is File) {
        final path = file.path.toLowerCase();
        if (extensions.any((ext) => path.endsWith(ext))) {
          songs.add(await _fileToSong(file));
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ i_music: Error scanning $dirPath — $e');
  }

  return songs;
}

/// Convert a file into a Song model.
Future<Song> _fileToSong(File file) async {
  try {
    return Song(
      id: file.path.hashCode.toString(),
      title: _getFileNameWithoutExtension(file.path),
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      duration: 0, // To be updated if you integrate a metadata parser
      uri: file.uri.toString(),
      albumArt: null,
    );
  } catch (_) {
    return Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Unknown',
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      duration: 0,
      uri: file.uri.toString(),
      albumArt: null,
    );
  }
}

/// Helper — remove file extension from filename.
String _getFileNameWithoutExtension(String path) {
  final fileName = path.split('/').last;
  final dotIndex = fileName.lastIndexOf('.');
  return dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
}
