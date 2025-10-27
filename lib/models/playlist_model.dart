// models/playlist_model.dart
import 'package:hive/hive.dart';
import 'song_model.dart';

part 'playlist_model.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String? description;
  
  @HiveField(3)
  final List<Song> songs;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  DateTime lastModified;
  
  @HiveField(6)
  final String? coverArt;
  
  @HiveField(7)
  final bool isSystemPlaylist;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.songs,
    DateTime? createdAt,
    DateTime? lastModified,
    this.coverArt,
    this.isSystemPlaylist = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  // 🆕 GETTERS
  int get songCount => songs.length;
  
  Duration get totalDuration {
    return songs.fold(
      Duration.zero,
      (total, song) => total + Duration(milliseconds: song.duration),
    );
  }
  
  String get formattedTotalDuration {
    final totalMinutes = totalDuration.inMinutes;
    final totalSeconds = totalDuration.inSeconds.remainder(60);
    return '${totalMinutes}m ${totalSeconds}s';
  }

  // 🆕 METHODS
  void addSong(Song song) {
    songs.add(song);
    lastModified = DateTime.now();
  }

  void removeSong(Song song) {
    songs.removeWhere((s) => s.id == song.id);
    lastModified = DateTime.now();
  }

  bool containsSong(Song song) {
    return songs.any((s) => s.id == song.id);
  }

  void reorderSongs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Song item = songs.removeAt(oldIndex);
    songs.insert(newIndex, item);
    lastModified = DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist($name - $songCount songs)';
}