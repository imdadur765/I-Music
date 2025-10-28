// models/song_model.dart
import 'package:hive/hive.dart';

part 'song_model.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String uri;
  
  @HiveField(2)
  final String title;
  
  @HiveField(3)
  final String artist;
  
  @HiveField(4)
  final String? album;
  
  @HiveField(5)
  final int duration;
  
  @HiveField(6)
  final String? albumArt;

  // 🆕 NEW FIELDS FOR ENHANCED FUNCTIONALITY
  @HiveField(7)
  final String? genre;
  
  @HiveField(8)
  final int? trackNumber;
  
  @HiveField(9)
  final int? year;
  
  @HiveField(10)
  final String? composer;
  
  @HiveField(11)
  final int playCount;
  
  @HiveField(12)
  final DateTime lastPlayed;
  
  @HiveField(13)
  final DateTime dateAdded;
  
  @HiveField(14)
  final bool isFavorite;

  // 🆕 ENHANCED CONSTRUCTOR WITH DEFAULT VALUES
  Song({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.albumArt,
    this.genre,
    this.trackNumber,
    this.year,
    this.composer,
    this.playCount = 0,
    DateTime? lastPlayed,
    DateTime? dateAdded,
    this.isFavorite = false,
  })  : lastPlayed = lastPlayed ?? DateTime.now(),
        dateAdded = dateAdded ?? DateTime.now();

  // 🆕 FACTORY CONSTRUCTOR FOR JSON SERIALIZATION
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      uri: json['uri'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'],
      duration: json['duration'] ?? 0,
      albumArt: json['albumArt'],
      genre: json['genre'],
      trackNumber: json['trackNumber'],
      year: json['year'],
      composer: json['composer'],
      playCount: json['playCount'] ?? 0,
      lastPlayed: json['lastPlayed'] != null 
          ? DateTime.parse(json['lastPlayed']) 
          : null,
      dateAdded: json['dateAdded'] != null 
          ? DateTime.parse(json['dateAdded']) 
          : null,
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  // 🆕 TO JSON METHOD FOR SERIALIZATION
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uri': uri,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'albumArt': albumArt,
      'genre': genre,
      'trackNumber': trackNumber,
      'year': year,
      'composer': composer,
      'playCount': playCount,
      'lastPlayed': lastPlayed.toIso8601String(),
      'dateAdded': dateAdded.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  // 🆕 COPY WITH METHOD FOR IMMUTABLE UPDATES
  Song copyWith({
    String? id,
    String? uri,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? albumArt,
    String? genre,
    int? trackNumber,
    int? year,
    String? composer,
    int? playCount,
    DateTime? lastPlayed,
    DateTime? dateAdded,
    bool? isFavorite,
  }) {
    return Song(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      albumArt: albumArt ?? this.albumArt,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      composer: composer ?? this.composer,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // 🆕 INCREMENT PLAY COUNT METHOD
  Song incrementPlayCount() {
    return copyWith(
      playCount: playCount + 1,
      lastPlayed: DateTime.now(),
    );
  }

  // 🆕 TOGGLE FAVORITE METHOD
  Song toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }

  // 🆕 GETTER FOR DISPLAY DURATION
  String get formattedDuration {
    final duration = Duration(milliseconds: this.duration);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 🆕 GETTER FOR FILE EXTENSION
  String get fileExtension {
    try {
      return uri.split('.').last.toLowerCase();
    } catch (e) {
      return 'mp3'; // Default assumption
    }
  }

  // 🆕 CHECK IF SONG IS VALID FOR PLAYBACK
  bool get isValidForPlayback {
    return uri.isNotEmpty && duration > 0;
  }

  // ✅ ENHANCED EQUALITY CHECK
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(id, uri);

  String? get filePath => null;

  // ✅ ENHANCED TO STRING METHOD
  @override
  String toString() => 'Song($title - $artist | $formattedDuration)';

  // 🆕 COMPARE METHODS FOR SORTING
  int compareByTitle(Song other) => title.compareTo(other.title);
  int compareByArtist(Song other) => artist.compareTo(other.artist);
  int compareByAlbum(Song other) => (album ?? '').compareTo(other.album ?? '');
  int compareByDateAdded(Song other) => dateAdded.compareTo(other.dateAdded);
  int compareByPlayCount(Song other) => other.playCount.compareTo(playCount);
}

// 🆕 EXTENSION FOR LIST OPERATIONS
extension SongListExtensions on List<Song> {
  List<Song> sortByTitle() {
    return [...this]..sort((a, b) => a.compareByTitle(b));
  }

  List<Song> sortByArtist() {
    return [...this]..sort((a, b) => a.compareByArtist(b));
  }

  List<Song> sortByAlbum() {
    return [...this]..sort((a, b) => a.compareByAlbum(b));
  }

  List<Song> sortByDateAdded() {
    return [...this]..sort((a, b) => a.compareByDateAdded(b));
  }

  List<Song> sortByPlayCount() {
    return [...this]..sort((a, b) => a.compareByPlayCount(b));
  }

  List<Song> get favorites {
    return where((song) => song.isFavorite).toList();
  }

  List<Song> get validSongs {
    return where((song) => song.isValidForPlayback).toList();
  }

  List<Song> search(String query) {
    if (query.isEmpty) return this;
    final lowercaseQuery = query.toLowerCase();
    return where((song) =>
        song.title.toLowerCase().contains(lowercaseQuery) ||
        song.artist.toLowerCase().contains(lowercaseQuery) ||
        (song.album ?? '').toLowerCase().contains(lowercaseQuery) ||
        (song.genre ?? '').toLowerCase().contains(lowercaseQuery)).toList();
  }
}