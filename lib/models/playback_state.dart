// models/playback_state.dart
import 'package:hive/hive.dart';
import 'song_model.dart';

part 'playback_state.g.dart';

@HiveType(typeId: 4)
class MusicPlaybackState {  // ✅ Renamed to avoid conflict
  @HiveField(0)
  final Song? currentSong;
  
  @HiveField(1)
  final Duration position;
  
  @HiveField(2)
  final Duration duration;
  
  @HiveField(3)
  final bool isPlaying;
  
  @HiveField(4)
  final bool isShuffling;
  
  @HiveField(5)
  final int repeatMode;
  
  @HiveField(6)
  final List<Song> currentQueue;

  MusicPlaybackState({
    this.currentSong,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isShuffling,
    required this.repeatMode,
    required this.currentQueue,
  });

  MusicPlaybackState copyWith({
    Song? currentSong,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isShuffling,
    int? repeatMode,
    List<Song>? currentQueue,
  }) {
    return MusicPlaybackState(
      currentSong: currentSong ?? this.currentSong,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffling: isShuffling ?? this.isShuffling,
      repeatMode: repeatMode ?? this.repeatMode,
      currentQueue: currentQueue ?? this.currentQueue,
    );
  }

  static MusicPlaybackState initial() {
    return MusicPlaybackState(
      currentSong: null,
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: false,
      isShuffling: false,
      repeatMode: 0,
      currentQueue: [],
    );
  }
}