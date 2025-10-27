// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_media_store_service.dart';
import '../services/file_system_scanner.dart';
import '../models/song_model.dart';

final songsProvider = FutureProvider<List<Song>>((ref) async {
  try {
    // Try MediaStore first
    final mediaStoreService = RealMediaStoreService();
    final mediaStoreSongs = await mediaStoreService.fetchSongs();
    
    // If MediaStore returns actual songs (not just fallback), use them
    if (mediaStoreSongs.isNotEmpty && 
        mediaStoreSongs.first.title != 'No songs found on device') {
      print('i_music: Using ${mediaStoreSongs.length} songs from MediaStore');
      return mediaStoreSongs;
    }
    
    // If MediaStore fails, try file system scanning
    print('i_music: MediaStore failed, trying file system scan...');
    final fileScanner = FileSystemScanner();
    final fileSystemSongs = await fileScanner.scanForAudioFiles();
    
    if (fileSystemSongs.isNotEmpty) {
      print('i_music: Using ${fileSystemSongs.length} songs from file system');
      return fileSystemSongs;
    }
    
    // If both methods fail, return empty list
    print('i_music: Both methods failed, returning empty list');
    return [];
    
  } catch (e) {
    print('i_music: Error in songs provider: $e');
    return [];
  }
});