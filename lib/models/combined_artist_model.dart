import 'local_song_model.dart';

class CombinedArtist {
  final String id;
  final String name;
  final String imageUrl;
  final String followers;
  final int popularity;
  final List<String> genres;
  final List<LocalSong> localSongs;
  final int localSongsCount;

  CombinedArtist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.followers,
    required this.popularity,
    required this.genres,
    required this.localSongs,
    required this.localSongsCount,
  });

  factory CombinedArtist.fromSpotifyArtist(Artist spotifyArtist, List<LocalSong> localSongs) {
    return CombinedArtist(
      id: spotifyArtist.id,
      name: spotifyArtist.name,
      imageUrl: spotifyArtist.imageUrl,
      followers: spotifyArtist.followers,
      popularity: spotifyArtist.popularity,
      genres: spotifyArtist.genres,
      localSongs: localSongs,
      localSongsCount: localSongs.length,
    );
  }
}

// Your existing Spotify Artist model
class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final int songsCount;
  final String followers;
  final List<Song> popularSongs;
  final int popularity;
  final List<String> genres;

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.songsCount,
    required this.followers,
    required this.popularSongs,
    this.popularity = 0,
    this.genres = const [],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Artist',
      imageUrl: json['imageUrl'] ?? json['images']?[0]?['url'] ?? '',
      songsCount: json['songsCount'] ?? 0,
      followers: json['followers'] ?? '0',
      popularSongs: [],
      popularity: json['popularity'] ?? 0,
      genres: List<String>.from(json['genres'] ?? []),
    );
  }
}

class Song {
  final String id;
  final String title;
  final String duration;
  final String artist;
  final String albumArt;
  final String? previewUrl;
  final int popularity;
  final String? album;

  Song({
    required this.id,
    required this.title,
    required this.duration,
    required this.artist,
    required this.albumArt,
    this.previewUrl,
    this.popularity = 0,
    this.album,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown Song',
      duration: json['duration'] ?? '0:00',
      artist: json['artist'] ?? 'Unknown Artist',
      albumArt: json['albumArt'] ?? json['album']?['images']?[0]?['url'] ?? '',
      previewUrl: json['preview_url'] ?? json['previewUrl'],
      popularity: json['popularity'] ?? 0,
      album: json['album']?['name'],
    );
  }
}