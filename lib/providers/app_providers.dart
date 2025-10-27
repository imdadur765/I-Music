// lib/providers/app_providers.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart'; // ✅ ADD THIS IMPORT
import 'package:i_music/main.dart';
import 'package:i_music/services/background_audio_service.dart';
import '../models/song_model.dart';

// 🎵 AUDIO HANDLER PROVIDER - FIXED: Use AudioHandler instead of BackgroundAudioHandler
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
      return Song(
        id: data['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        uri: data['uri']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Unknown Title',
        artist: data['artist']?.toString() ?? 'Unknown Artist',
        album: data['album']?.toString(),
        duration: (data['duration'] as int?) ?? 0,
        albumArt: data['albumArt']?.toString(),
        albumId: (data['albumId'] as int?) ?? 0, // ✅ FIX: albumId add kiya
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