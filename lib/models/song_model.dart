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

  // ✅ IMPROVED: filePath getter
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

  String get formattedDuration {
    final duration = Duration(milliseconds: this.duration);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isValidForPlayback {
    return uri.isNotEmpty && duration > 0;
  }

  @override
  String toString() => 'Song($title - $artist | $formattedDuration | MediaStoreID: $mediaStoreId)';

  // ... (rest of your Song model remains same)
}