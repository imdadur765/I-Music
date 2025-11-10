// lib/providers/audio_provider.dart - UPDATED FOR audio_service 0.18.18
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../services/background_audio_service.dart';
import '../models/song_model.dart';

// 🎵 Main audio handler provider - this will be overridden in main.dart
final audioHandlerProvider = Provider<BackgroundAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler should be provided in main.dart');
});

// 🎵 Audio player service provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return AudioPlayerService(audioHandler);
});

// 🎵 Current song provider
final currentSongProvider = StateProvider<Song?>((ref) => null);

// 🎵 Playback state provider - UPDATED for audio_service 0.18.18
final isPlayingProvider = StreamProvider<bool>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.playbackState.map((state) => state.playing);
});

// 🎵 Current MediaItem provider - ADDED for audio_service 0.18.18
final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.mediaItem;
});

// 🎵 Playback state provider - ADDED for audio_service 0.18.18
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.playbackState;
});

// 🎵 Songs list provider
final songsProvider = FutureProvider<List<Song>>((ref) async {
  // This will be implemented in main.dart
  return [];
});

// ✅ UPDATED: Duration provider (from audio handler)
final durationProvider = StreamProvider<Duration?>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.durationStream;
});

// ✅ UPDATED: Position provider (from audio handler)  
final positionProvider = StreamProvider<Duration>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.positionStream;
});

// ✅ UPDATED: Buffered position provider
final bufferedPositionProvider = StreamProvider<Duration>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.bufferedPositionStream;
});

// ✅ UPDATED: Processing state provider
final processingStateProvider = StreamProvider<ProcessingState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.processingStateStream;
});

// ✅ UPDATED: Player state provider
final playerStateProvider = StreamProvider<PlayerState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.playerStateStream;
});

// ✅ ADDED: Volume provider
final volumeProvider = StateProvider<double>((ref) => 1.0);

// ✅ ADDED: Playback speed provider
final speedProvider = StateProvider<double>((ref) => 1.0);

// ✅ ADDED: Queue provider
final queueProvider = StateProvider<List<Song>>((ref) => []);

// ✅ ADDED: Current index provider
final currentIndexProvider = StateProvider<int>((ref) => 0);

// ✅ ADDED: Loop mode provider
final loopModeProvider = StateProvider<LoopMode>((ref) => LoopMode.off);

// ✅ ADDED: Shuffle mode provider  
final shuffleModeProvider = StateProvider<bool>((ref) => false);

// ✅ ADDED: Audio Service state provider
final audioServiceStateProvider = StreamProvider<AudioServiceState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return audioHandler.playbackState.map((state) {
    if (state.playing) {
      return AudioServiceState.playing;
    // ignore: unrelated_type_equality_checks
    } else if (state.processingState == ProcessingState.ready) {
      return AudioServiceState.paused;
    } else {
      return AudioServiceState.stopped;
    }
  });
});

// 🎵 Audio Player Service Class - UPDATED FOR audio_service 0.18.18
class AudioPlayerService {
  final BackgroundAudioHandler _audioHandler;

  AudioPlayerService(this._audioHandler);

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    try {
      final queue = playlist ?? [song];
      await _audioHandler.setSong(song, queue);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> togglePlayback() async {
    try {
      final playbackState = _audioHandler.playbackState.value;
      if (playbackState.playing == true) {
        await _audioHandler.pause();
      } else {
        await _audioHandler.play();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> skipToNext() async {
    try {
      await _audioHandler.skipToNext();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _audioHandler.skipToPrevious();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioHandler.seek(position);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _audioHandler.stop();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _audioHandler.setVolume(volume);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ UPDATED: Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _audioHandler.setSpeed(speed);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ UPDATED: Get current position
  Duration get currentPosition => _audioHandler.position;

  // ✅ UPDATED: Get total duration
  Duration? get totalDuration => _audioHandler.duration;

  // ✅ ADDED: Debug notification art
  Future<void> debugNotificationArt() async {
    await _audioHandler.customAction('debugNotificationArt');
  }

  // ✅ ADDED: Get current playback state
  PlaybackState get playbackState => _audioHandler.playbackState.value;

  // ✅ ADDED: Get current media item
  MediaItem? get currentMediaItem => _audioHandler.mediaItem.value;
}

// ✅ UPDATED: Loop Mode Enum
enum LoopMode {
  off,
  one,
  all,
}

// ✅ ADDED: Audio Service State Enum
enum AudioServiceState {
  stopped,
  paused,
  playing,
}