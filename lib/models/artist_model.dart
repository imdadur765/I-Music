// ✅ SINGLE MODEL FOR ENTIRE APP
class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final int songsCount;
  final String followers;
  final List<Song> popularSongs;
  final int popularity;
  final List<String> genres;
  final List<LocalSong> localSongs; // ✅ Local songs added here
  final int localSongsCount;
   String get formattedGenres {
    if (genres.isEmpty) return 'Various Genres';
    if (genres.length <= 2) return genres.join(', ');
    return '${genres.take(2).join(', ')}...';
  }
   bool get hasSpotifyData {
    return followers != 'Local Artist' && popularity > 0;
  }

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.songsCount,
    required this.followers,
    required this.popularSongs,
    this.popularity = 0,
    this.genres = const [],
    this.localSongs = const [],
    this.localSongsCount = 0,
  });

  // Factory constructor for Spotify API
  factory Artist.fromSpotifyJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Artist',
      imageUrl: json['images']?[0]?['url'] ?? '',
      songsCount: 0, // Spotify doesn't provide this
      followers: _formatFollowers(json['followers']?['total'] ?? 0),
      popularSongs: [],
      popularity: json['popularity'] ?? 0,
      genres: List<String>.from(json['genres'] ?? []),
      localSongs: const [],
      localSongsCount: 0,
    );
  }

  // Factory constructor for combined data
  factory Artist.fromCombinedData({
    required Artist spotifyArtist,
    required List<LocalSong> localSongs,
  }) {
    return Artist(
      id: spotifyArtist.id,
      name: spotifyArtist.name,
      imageUrl: spotifyArtist.imageUrl,
      songsCount: spotifyArtist.songsCount,
      followers: spotifyArtist.followers,
      popularSongs: spotifyArtist.popularSongs,
      popularity: spotifyArtist.popularity,
      genres: spotifyArtist.genres,
      localSongs: localSongs,
      localSongsCount: localSongs.length,
    );
  }

  // Factory constructor for local-only artists
  factory Artist.fromLocalData({
    required String name,
    required List<LocalSong> localSongs,
  }) {
    return Artist(
      id: name.hashCode.toString(),
      name: name,
      imageUrl: '',
      songsCount: localSongs.length,
      followers: 'Local Artist',
      popularSongs: [],
      popularity: 0,
      genres: ['Local'],
      localSongs: localSongs,
      localSongsCount: localSongs.length,
    );
  }

  static String _formatFollowers(int followers) {
    if (followers >= 1000000) {
      return '${(followers / 1000000).toStringAsFixed(1)}M';
    } else if (followers >= 1000) {
      return '${(followers / 1000).toStringAsFixed(1)}K';
    }
    return followers.toString();
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

class LocalSong {
  final String id;
  final String title;
  final String album;
  final String artist;
  final String path;
  final int duration;
  final int size;
  final String albumId;
  final String uri;

  LocalSong({
    required this.id,
    required this.title,
    required this.album,
    required this.artist,
    required this.path,
    required this.duration,
    required this.size,
    this.albumId = '',
    this.uri = '',
  });

  String get formattedDuration {
    final minutes = (duration / 1000) ~/ 60;
    final seconds = ((duration / 1000) % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  get albumArt => null;
  
}