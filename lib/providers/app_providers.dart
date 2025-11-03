// lib/providers/app_providers.dart - FULLY FIXED AND STREAM-SYNCED ⚡
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:i_music/main.dart';
import '../models/song_model.dart';
import '../services/background_audio_service.dart';

/// 🎧 AUDIO HANDLER PROVIDER
final audioHandlerProvider = Provider<AudioHandler>((ref) => globalAudioHandler);

/// 🎵 STREAM PROVIDERS (LIVE UPDATES FROM AUDIO SERVICE)
final currentSongProvider = StreamProvider<Song?>((ref) {
  return globalAudioHandler.mediaItem.map((mediaItem) {
    if (mediaItem == null) return null;
    // Convert MediaItem to our Song model
    return Song(
      id: mediaItem.id,
      uri: mediaItem.extras?['uri'] ?? '',
      title: mediaItem.title,
      artist: mediaItem.artist ?? 'Unknown Artist',
      album: mediaItem.album,
      albumArt: mediaItem.artUri?.toString(),
      duration: mediaItem.duration?.inMilliseconds ?? 0,
      mediaStoreId: int.tryParse(mediaItem.extras?['mediaStoreId']?.toString() ?? '0') ?? 0,
      genre: mediaItem.genre,
      trackNumber: mediaItem.extras?['trackNumber'] ?? 0,
      year: mediaItem.extras?['year'] ?? 0,
      composer: mediaItem.extras?['composer'],
      playCount: 0,
      lastPlayed: DateTime.now(),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );
  });
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  return globalAudioHandler.playbackState.map((state) => state.playing).distinct();
});

final playbackPositionProvider = StreamProvider<Duration>((ref) {
  return globalAudioHandler.playbackState
      .map((state) => state.position)
      .distinct();
});

/// 🎵 PLAYLIST STATE PROVIDER (STATIC)
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);

/// 🎵 SONG FETCH PROVIDER
final songsProvider = FutureProvider<List<Song>>((ref) async {
  try {
    final songs = await _fetchSongsFromDevice();
    return songs;
  } catch (e) {
    debugPrint('Error fetching songs: $e');
    return [];
  }
});

/// 📱 METHOD CHANNEL TO FETCH DEVICE SONGS
const MethodChannel _methodChannel = MethodChannel('i_music/media_store');

Future<List<Song>> _fetchSongsFromDevice() async {
  try {
    final List<dynamic> songsData = await _methodChannel.invokeMethod('getAllSongs');

    final List<Song> songs = songsData.map((data) {
      final nativeId = data['id'] as int?;
      final mediaStoreId = nativeId ?? 0;

      return Song(
        id: mediaStoreId.toString(),
        uri: data['uri']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Unknown Title',
        artist: data['artist']?.toString() ?? 'Unknown Artist',
        album: data['album']?.toString(),
        duration: (data['duration'] as int?) ?? 0,
        albumArt: data['albumArt']?.toString(),
        mediaStoreId: mediaStoreId,
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

/// ▶️ PLAY SONG FUNCTION
void playSong(WidgetRef ref, Song song, List<Song> queue) async {
  try {
    debugPrint('🎵 Playing song: ${song.title}');
    final audioHandler = ref.read(audioHandlerProvider);
    ref.read(currentPlaylistProvider.notifier).state = queue;

    if (audioHandler is BackgroundAudioHandler) {
      await audioHandler.setSong(song, queue);
    } else {
      debugPrint('❌ AudioHandler is not BackgroundAudioHandler');
    }
  } catch (e) {
    debugPrint('❌ Error playing song: $e');
  }
}

/// ⏯️ TOGGLE PLAY / PAUSE
void togglePlayPause(WidgetRef ref) async {
  try {
    final isPlaying = ref.read(isPlayingProvider).value ?? false;
    final audioHandler = ref.read(audioHandlerProvider);

    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  } catch (e) {
    debugPrint('❌ Error toggling play/pause: $e');
  }
}

/// ⏭️ SKIP TO NEXT
void skipToNext(WidgetRef ref) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.skipToNext();
  } catch (e) {
    debugPrint('❌ Error skipping to next: $e');
  }
}

/// ⏮️ SKIP TO PREVIOUS
void skipToPrevious(WidgetRef ref) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.skipToPrevious();
  } catch (e) {
    debugPrint('❌ Error skipping to previous: $e');
  }
}

/// ⏩ SEEK TO POSITION
void seekTo(WidgetRef ref, Duration position) async {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.seek(position);
  } catch (e) {
    debugPrint('❌ Error seeking: $e');
  }
}
