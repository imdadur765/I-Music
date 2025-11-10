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

  // ✅ CRITICAL: mediaStoreId for album art
  @HiveField(15)
  final int mediaStoreId;

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
    required this.mediaStoreId,
  })  : lastPlayed = lastPlayed ?? DateTime.now(),
        dateAdded = dateAdded ?? DateTime.now();

  // ✅ FIXED: toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'uri': uri,
      'mediaStoreId': mediaStoreId,
      'genre': genre,
    };
  }

  // ✅ FIXED: fromJson factory
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      duration: json['duration'],
      uri: json['uri'],
      mediaStoreId: json['mediaStoreId'],
      genre: json['genre'],
    );
  }

  // ✅ FIXED: IMPROVED filePath getter - NOW INSIDE CLASS
  String? get filePath {
    try {
      if (uri.startsWith('file://')) {
        return uri.substring(7);
      }
      if (uri.startsWith('content://')) {
        return uri;
      }
      if (uri.contains('/storage/') || uri.contains('/data/')) {
        return uri;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ FIXED: formattedDuration getter - NOW INSIDE CLASS
  String get formattedDuration {
    final duration = Duration(milliseconds: this.duration);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ✅ FIXED: isValidForPlayback getter - NOW INSIDE CLASS
  bool get isValidForPlayback {
    return uri.isNotEmpty && duration > 0;
  }

  // ✅ FIXED: toString method - NOW INSIDE CLASS
  @override
  String toString() => 'Song($title - $artist | $formattedDuration | MediaStoreID: $mediaStoreId)';

  // ✅ ADD: CopyWith method for easy updates
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
    int? mediaStoreId,
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
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
    );
  }

  // ✅ ADD: Equals method for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri;

  @override
  int get hashCode => id.hashCode ^ uri.hashCode;
}