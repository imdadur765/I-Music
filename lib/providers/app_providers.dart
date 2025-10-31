// lib/providers/app_providers.dart - COMPLETELY FIXED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:i_music/main.dart';
import 'package:i_music/services/background_audio_service.dart';
// ❌ REMOVE: Unused import
// import 'package:i_music/services/background_audio_service.dart';
import '../models/song_model.dart';

// 🎵 AUDIO HANDLER PROVIDER
final audioHandlerProvider = Provider<AudioHandler>((ref) => globalAudioHandler);

// 🎵 AUDIO STATE PROVIDERS
final currentSongProvider = StateProvider<Song?>((ref) => null);
final isPlayingProvider = StateProvider<bool>((ref) => false);
final playbackPositionProvider = StateProvider<Duration>((ref) => Duration.zero);
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);

// 🎵 SONGS DATA PROVIDER
final songsProvider = FutureProvider<List<Song>>((ref) async {
  try {
    final songs = await _fetchSongsFromDevice();
    return songs;
  } catch (e) {
    debugPrint('Error fetching songs: $e');
    return [];
  }
});

// METHOD CHANNEL
const MethodChannel _methodChannel = MethodChannel('i_music/media_store');

Future<List<Song>> _fetchSongsFromDevice() async {
  try {
    final List<dynamic> songsData = await _methodChannel.invokeMethod('getAllSongs');

    final List<Song> songs = songsData.map((data) {
      // ✅ FIXED: Now including mediaStoreId and all required fields
      final nativeId = data['id'] as int?;
      final mediaStoreId = nativeId ?? 0;
      
      return Song(
        id: mediaStoreId.toString(), // Convert to string for app ID
        uri: data['uri']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Unknown Title',
        artist: data['artist']?.toString() ?? 'Unknown Artist',
        album: data['album']?.toString(),
        duration: (data['duration'] as int?) ?? 0,
        albumArt: data['albumArt']?.toString(),
        // ✅ ADDED: All required fields including mediaStoreId
        mediaStoreId: mediaStoreId, // CRITICAL: For album art
        genre: data['genre']?.toString(),
        trackNumber: (data['trackNumber'] as int?) ?? 0,
        year: (data['year'] as int?) ?? 0,
        composer: data['composer']?.toString(),
        playCount: 0,
        lastPlayed: DateTime.now(),
        dateAdded: DateTime.now(),
        isFavorite: false,
      );
    }).where((song) => song.duration > 10000).toList();

    debugPrint('✅ Fetched ${songs.length} songs from device');
    return songs;
  } on PlatformException catch (e) {
    debugPrint('❌ Failed to fetch songs: ${e.message}');
    return [];
  } catch (e) {
    debugPrint('❌ Unexpected error fetching songs: $e');
    return [];
  }
}

// ✅ ADDED: Play song function using audio handler
void playSong(WidgetRef ref, Song song, List<Song> queue) async {
  try {
    debugPrint('🎵 Playing song: ${song.title}');
    
    final audioHandler = ref.read(audioHandlerProvider);
    
    // Update current song state
    ref.read(currentSongProvider.notifier).state = song;
    ref.read(currentPlaylistProvider.notifier).state = queue;
    
    // Use custom method to set song in background audio handler
    if (audioHandler is BackgroundAudioHandler) {
      await audioHandler.setSong(song, queue);
    } else {
      debugPrint('❌ AudioHandler is not BackgroundAudioHandler');
    }
  } catch (e) {
    debugPrint('❌ Error playing song: $e');
  }
}

// ✅ ADDED: Toggle play/pause
void togglePlayPause(WidgetRef ref) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    final isPlaying = ref.read(isPlayingProvider);
    
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    
    ref.read(isPlayingProvider.notifier).state = !isPlaying;
  } catch (e) {
    debugPrint('❌ Error toggling play/pause: $e');
  }
}

// ✅ ADDED: Skip to next
void skipToNext(WidgetRef ref) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.skipToNext();
  } catch (e) {
    debugPrint('❌ Error skipping to next: $e');
  }
}

// ✅ ADDED: Skip to previous
void skipToPrevious(WidgetRef ref) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.skipToPrevious();
  } catch (e) {
    debugPrint('❌ Error skipping to previous: $e');
  }
}

// ✅ ADDED: Seek to position
void seekTo(WidgetRef ref, Duration position) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.seek(position);
  } catch (e) {
    debugPrint('❌ Error seeking: $e');
  }
}