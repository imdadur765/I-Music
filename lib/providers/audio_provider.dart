import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/services/background_audio_service.dart';
import '../models/song_model.dart';

// 🎵 ALL PROVIDERS - EK HI JAGAH
final audioHandlerProvider = Provider<BackgroundAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler should be provided via globalAudioHandler');
});

final currentSongProvider = StateProvider<Song?>((ref) => null);
final isPlayingProvider = StateProvider<bool>((ref) => false);
final playbackPositionProvider = StateProvider<Duration>((ref) => Duration.zero);
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);