import 'package:flutter/foundation.dart';
import '../models/artist_model.dart' as artist_model;
import '../models/local_song_model.dart' as local_song_model;
import 'spotify_service.dart';
import 'local_songs_service.dart';

class CombinedArtistService {
  final LocalSongsService _localSongsService = LocalSongsService();
  
  // Cache to avoid duplicate processing
  final Map<String, artist_model.Artist> _artistCache = {};
  
  Future<List<artist_model.Artist>> getCombinedArtists() async {
    try {
      // Step 1: Get unique artists from local songs
      final localArtists = await _localSongsService.getUniqueArtists();
      if (kDebugMode) {
        print('🎵 Found ${localArtists.length} local artists');
      }
      
      // Step 2: Use batch processing for Spotify data
      final batchArtistsData = await _getBatchArtistsData(localArtists);
      
      List<artist_model.Artist> combinedArtists = [];
      
      // Step 3: Create combined artists efficiently
      // Step 3: Create combined artists efficiently
for (final artistName in localArtists) {
  try {
    // Get local songs for this artist
    final List<local_song_model.LocalSong> localSongs = await _localSongsService.getSongsByArtist(artistName);
    
    // Convert to artist model LocalSong
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
    
    // ✅ FIXED: Get Spotify data from batch results
    Map<String, dynamic> artistData = {'localName': artistName, 'spotifyArtist': null};
    for (final data in batchArtistsData) {
      if (data['localName'] == artistName) {
        artistData = data;
        break;
      }
    }
    
    artist_model.Artist combinedArtist;
    
    if (artistData['spotifyArtist'] != null) {
      final spotifyArtist = artist_model.Artist.fromSpotifyJson(artistData['spotifyArtist']);
      combinedArtist = artist_model.Artist.fromCombinedData(
        spotifyArtist: spotifyArtist,
        localSongs: artistLocalSongs,
      );
    } else {
      combinedArtist = artist_model.Artist.fromLocalData(
        name: artistName,
        localSongs: artistLocalSongs,
      );
    }
    
    // Cache the artist
    _artistCache[artistName] = combinedArtist;
    combinedArtists.add(combinedArtist);
    
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error processing $artistName: $e');
    }
    // Create local-only artist as fallback
    final localSongs = await _localSongsService.getSongsByArtist(artistName);
    final artistLocalSongs = localSongs.map((s) => artist_model.LocalSong(
      id: s.id,
      title: s.title,
      album: s.album,
      artist: s.artist,
      path: s.path,
      duration: s.duration,
      size: s.size,
    )).toList();
    
    combinedArtists.add(artist_model.Artist.fromLocalData(
      name: artistName,
      localSongs: artistLocalSongs,
    ));
  }
}
      
      // Sort by number of local songs (descending)
      combinedArtists.sort((a, b) => b.localSongsCount.compareTo(a.localSongsCount));
      
      if (kDebugMode) {
        print('✅ Created ${combinedArtists.length} combined artists');
      }
      
      return combinedArtists;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Combined service error: $e');
      }
      return _getDemoArtists();
    }
  }
  
  // NEW: Batch processing for Spotify data
  Future<List<Map<String, dynamic>>> _getBatchArtistsData(List<String> artistNames) async {
    try {
      // Filter out already cached artists
      final newArtists = artistNames.where((name) => !_artistCache.containsKey(name)).toList();
      
      if (newArtists.isEmpty) {
        return [];
      }
      
      if (kDebugMode) {
        print('🔄 Batch processing ${newArtists.length} new artists');
      }
      
      final result = await SpotifyService.getBatchArtistsData(newArtists);
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Batch processing failed: $e');
      }
      return [];
    }
  }
  
  Future<List<artist_model.Artist>> searchCombinedArtists(String query) async {
    // First check cache
    final cachedResults = _artistCache.values.where((artist) => 
      artist.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
    
    if (cachedResults.isNotEmpty) {
      return cachedResults;
    }
    
    // If not in cache, do full search
    final allArtists = await getCombinedArtists();
    return allArtists.where((artist) => 
      artist.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Clear cache (call this when songs change)
  void clearCache() {
    _artistCache.clear();
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
    ];
  }
}