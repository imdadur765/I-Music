import '../models/artist_model.dart';
import 'spotify_service.dart';

class ArtistService {
  final bool _useSpotify = true;

  // Helper function to format duration from milliseconds to "mm:ss"
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<List<Artist>> getArtists({String searchQuery = ''}) async {
    try {
      if (!_useSpotify) {
        return _getDemoArtists(searchQuery);
      }

      if (searchQuery.isNotEmpty) {
        final artists = await SpotifyService.searchArtists(searchQuery);
        if (artists.isNotEmpty) {
          return artists;
        }
      } else {
        return await _getPopularArtists();
      }

      return _getDemoArtists(searchQuery);

    } catch (e) {
      return _getDemoArtists(searchQuery);
    }
  }

  Future<List<Artist>> _getPopularArtists() async {
    try {
      final popularArtists = await SpotifyService.searchArtists('a', limit: 30);
      
      if (popularArtists.isNotEmpty) {
        popularArtists.sort((a, b) => b.popularity.compareTo(a.popularity));
        return popularArtists.take(20).toList();
      }
      
      return _getDemoArtists('');
    } catch (e) {
      return _getDemoArtists('');
    }
  }

  Future<Artist> getArtistDetails(String artistId) async {
    try {
      if (_useSpotify) {
        final artist = await SpotifyService.getArtist(artistId);
        final topTracks = await SpotifyService.getArtistTopTracks(artistId);
        
        // Convert song_model.Song to Artist's Song with proper formatting
        final List<Song> convertedSongs = topTracks.map((spotifySong) {
          // Convert duration from milliseconds to "mm:ss" format
          final String formattedDuration = _formatDuration(int.tryParse(spotifySong.duration as String) ?? 0);
          
          return Song(
            id: spotifySong.id,
            title: spotifySong.title,
            duration: formattedDuration,
            artist: spotifySong.artist,
            albumArt: spotifySong.albumArt ?? '',
            popularity: 0, // Default value since artist_model.Song requires it
          );
        }).toList();
        
        return Artist(
          id: artist.id,
          name: artist.name,
          imageUrl: artist.imageUrl,
          songsCount: artist.songsCount,
          followers: artist.followers,
          popularSongs: convertedSongs,
          popularity: artist.popularity,
          genres: artist.genres,
        );
      } else {
        return _getDemoArtists('').first;
      }
    } catch (e) {
      return _getDemoArtists('').first;
    }
  }

  Future<List<Song>> getArtistSongs(String artistId, String artistName) async {
    try {
      if (_useSpotify) {
        final topTracks = await SpotifyService.getArtistTopTracks(artistId);
        
        // Convert song_model.Song to Artist's Song with proper formatting
        return topTracks.map((spotifySong) {
          // Convert duration from milliseconds to "mm:ss" format
          final String formattedDuration = _formatDuration(int.tryParse(spotifySong.duration as String) ?? 0);
          
          return Song(
            id: spotifySong.id,
            title: spotifySong.title,
            duration: formattedDuration,
            artist: spotifySong.artist,
            albumArt: spotifySong.albumArt ?? '',
            popularity: 0, // Default value
          );
        }).toList();
      } else {
        return _getDemoSongs(artistName);
      }
    } catch (e) {
      return _getDemoSongs(artistName);
    }
  }

  // Demo data as fallback
  List<Artist> _getDemoArtists(String searchQuery) {
    final demoArtists = [
      Artist(
        id: '1',
        name: 'Arijit Singh',
        imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_00220221018091134_500x500.jpg',
        songsCount: 150,
        followers: '35.2M',
        popularSongs: _getDemoSongs('Arijit Singh'),
        popularity: 95,
        genres: ['Bollywood', 'Romantic'],
      ),
      Artist(
        id: '2',
        name: 'The Weeknd',
        imageUrl: 'https://i.scdn.co/image/ab6761610000e5eb214f3cf1cbe7139c1e26ffbb',
        songsCount: 89,
        followers: '53.4M',
        popularSongs: _getDemoSongs('The Weeknd'),
        popularity: 98,
        genres: ['R&B', 'Pop'],
      ),
      Artist(
        id: '3',
        name: 'Shreya Ghoshal',
        imageUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_00520221018090725_500x500.jpg',
        songsCount: 95,
        followers: '28.7M',
        popularSongs: _getDemoSongs('Shreya Ghoshal'),
        popularity: 92,
        genres: ['Bollywood', 'Classical'],
      ),
      Artist(
        id: '4',
        name: 'AP Dhillon',
        imageUrl: 'https://c.saavncdn.com/artists/AP_Dhillon_00520221018091134_500x500.jpg',
        songsCount: 34,
        followers: '12.8M',
        popularSongs: _getDemoSongs('AP Dhillon'),
        popularity: 88,
        genres: ['Punjabi', 'Hip-Hop'],
      ),
      Artist(
        id: '5',
        name: 'Taylor Swift',
        imageUrl: 'https://i.scdn.co/image/ab6761610000e5eb5a00969a4698c3132a15fbb0',
        songsCount: 245,
        followers: '61.3M',
        popularSongs: _getDemoSongs('Taylor Swift'),
        popularity: 99,
        genres: ['Pop', 'Country'],
      ),
      Artist(
        id: '6',
        name: 'Badshah',
        imageUrl: 'https://c.saavncdn.com/artists/Badshah_00420221018091134_500x500.jpg',
        songsCount: 67,
        followers: '15.3M',
        popularSongs: _getDemoSongs('Badshah'),
        popularity: 87,
        genres: ['Hip-Hop', 'Bollywood'],
      ),
    ];

    if (searchQuery.isNotEmpty) {
      return demoArtists
          .where((artist) => artist.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return demoArtists;
  }

  List<Song> _getDemoSongs(String artistName) {
    return [
      Song(
        id: '1',
        title: 'Popular Song 1',
        duration: '3:45',
        artist: artistName,
        albumArt: '',
        popularity: 80,
      ),
      Song(
        id: '2',
        title: 'Popular Song 2',
        duration: '4:20',
        artist: artistName,
        albumArt: '',
        popularity: 75,
      ),
      Song(
        id: '3',
        title: 'Popular Song 3',
        duration: '3:15',
        artist: artistName,
        albumArt: '',
        popularity: 70,
      ),
    ];
  }

  void dispose() {
    // Cleanup if needed
  }
}