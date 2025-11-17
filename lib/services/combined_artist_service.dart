import 'package:flutter/foundation.dart';
import '../models/artist_model.dart' as artist_model;
import '../models/local_song_model.dart' as local_song_model;
import 'spotify_service.dart';
import 'local_songs_service.dart';

class CombinedArtistService {
  final SpotifyService _spotifyService = SpotifyService();
  final LocalSongsService _localSongsService = LocalSongsService();
  
  Future<List<artist_model.Artist>> getCombinedArtists() async {
    try {
      // Step 1: Get unique artists from local songs
      final localArtists = await _localSongsService.getUniqueArtists();
      if (kDebugMode) {
        print('🎵 Found ${localArtists.length} local artists');
      }
      
      List<artist_model.Artist> combinedArtists = [];
      
      // Step 2: For each local artist, get Spotify data + local songs
      for (final artistName in localArtists) {
        try {
          // Get local songs for this artist (from local_song_model)
          final List<local_song_model.LocalSong> localSongs = await _localSongsService.getSongsByArtist(artistName);
          
          // Convert local_song_model.LocalSong -> artist_model.LocalSong
          final List<artist_model.LocalSong> artistLocalSongs = localSongs.map((s) {
            return artist_model.LocalSong(
              id: s.id,
              title: s.title,
              album: s.album,
              artist: s.artist,
              path: s.path,
              duration: s.duration,
              size: s.size,
            );
          }).toList();
          
          // Try to get Spotify data
          artist_model.Artist? spotifyArtist;
          try {
            final spotifyArtists = await _spotifyService.searchArtists(artistName, limit: 1);
            if (spotifyArtists.isNotEmpty) {
              spotifyArtist = spotifyArtists.first;
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Spotify search failed for $artistName: $e');
            }
          }
          
          // Create combined artist
          final combinedArtist = spotifyArtist != null
              ? artist_model.Artist.fromCombinedData(
                  spotifyArtist: spotifyArtist,
                  localSongs: artistLocalSongs,
                )
              : artist_model.Artist.fromLocalData(
                  name: artistName,
                  localSongs: artistLocalSongs,
                );
          
          combinedArtists.add(combinedArtist);
          if (kDebugMode) {
            print('✅ Created artist: $artistName - ${artistLocalSongs.length} local songs');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error processing $artistName: $e');
          }
        }
      }
      
      // Sort by number of local songs (descending)
      combinedArtists.sort((a, b) => b.localSongsCount.compareTo(a.localSongsCount));
      
      return combinedArtists;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Combined service error: $e');
      }
      return _getDemoArtists();
    }
  }
  
  Future<List<artist_model.Artist>> searchCombinedArtists(String query) async {
    final allArtists = await getCombinedArtists();
    return allArtists.where((artist) => 
      artist.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Demo data
  List<artist_model.Artist> _getDemoArtists() {
    return [
      artist_model.Artist.fromLocalData(
        name: 'Arijit Singh',
        localSongs: [
          artist_model.LocalSong(
            id: '1',
            title: 'Tum Hi Ho',
            album: 'Aashiqui 2',
            artist: 'Arijit Singh',
            path: '',
            duration: 262000,
            size: 5242880,
          ),
        ],
      ),
      artist_model.Artist.fromLocalData(
        name: 'The Weeknd',
        localSongs: [
          artist_model.LocalSong(
            id: '2',
            title: 'Blinding Lights',
            album: 'After Hours',
            artist: 'The Weeknd',
            path: '',
            duration: 200000,
            size: 4000000,
          ),
        ],
      ),
    ];
  }
}