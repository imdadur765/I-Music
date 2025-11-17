// providers/music_player_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist_model.dart';

class MusicPlayerState {
  final List<LocalSong>? currentQueue;
  final LocalSong? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  MusicPlayerState({
    this.currentQueue,
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  MusicPlayerState copyWith({
    List<LocalSong>? currentQueue,
    LocalSong? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return MusicPlayerState(
      currentQueue: currentQueue ?? this.currentQueue,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class MusicPlayerNotifier extends StateNotifier<MusicPlayerState> {
  MusicPlayerNotifier() : super(MusicPlayerState());

  void playSong(LocalSong song, List<LocalSong> queue) {
    state = state.copyWith(
      currentSong: song,
      currentQueue: queue,
      isPlaying: true,
      position: Duration.zero,
    );
  }

  void playPlaylist(List<LocalSong> playlist) {
    if (playlist.isEmpty) return;
    state = state.copyWith(
      currentSong: playlist.first,
      currentQueue: playlist,
      isPlaying: true,
      position: Duration.zero,
    );
  }

  void pause() {
    state = state.copyWith(isPlaying: false);
  }

  void resume() {
    state = state.copyWith(isPlaying: true);
  }

  void seek(Duration position) {
    state = state.copyWith(position: position);
  }

  void next() {
    if (state.currentQueue == null || state.currentSong == null) return;
    
    final currentIndex = state.currentQueue!.indexOf(state.currentSong!);
    if (currentIndex < state.currentQueue!.length - 1) {
      state = state.copyWith(
        currentSong: state.currentQueue![currentIndex + 1],
        position: Duration.zero,
      );
    }
  }

  void previous() {
    if (state.currentQueue == null || state.currentSong == null) return;
    
    final currentIndex = state.currentQueue!.indexOf(state.currentSong!);
    if (currentIndex > 0) {
      state = state.copyWith(
        currentSong: state.currentQueue![currentIndex - 1],
        position: Duration.zero,
      );
    }
  }
}

final musicPlayerProvider = StateNotifierProvider<MusicPlayerNotifier, MusicPlayerState>((ref) => MusicPlayerNotifier());