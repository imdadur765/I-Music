import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/spotify_config.dart';
import '../models/artist_model.dart' as artist_model;
import '../models/song_model.dart' as song_model;
import '../models/local_song_model.dart';

class SpotifyService {
  
  // Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse(SpotifyConfig.baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Search songs - COMPLETELY SECURE
  static Future<List<song_model.Song>> searchSongs(String query, {int limit = 20}) async {
    try {
      final url = Uri.parse('${SpotifyConfig.searchSongsUrl}?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => song_model.Song.fromJson(trackData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Search artists - COMPLETELY SECURE
  static Future<List<artist_model.Artist>> searchArtists(String query, {int limit = 20}) async {
    try {
      final url = Uri.parse('${SpotifyConfig.searchArtistsUrl}?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> artistsData = data['artists'];
          return artistsData.map((artistData) => artist_model.Artist.fromSpotifyJson(artistData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get artist details - COMPLETELY SECURE
  static Future<artist_model.Artist> getArtist(String artistId) async {
    try {
      final url = Uri.parse('${SpotifyConfig.getArtistUrl}/$artistId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return artist_model.Artist.fromSpotifyJson(data['artist']);
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get artist's top tracks - COMPLETELY SECURE
  static Future<List<song_model.Song>> getArtistTopTracks(String artistId) async {
    try {
      final url = Uri.parse('${SpotifyConfig.getArtistTopTracksUrl}/$artistId/top-tracks?market=IN');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => song_model.Song.fromJson(trackData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get track details - COMPLETELY SECURE
  static Future<song_model.Song> getTrack(String trackId) async {
    try {
      final url = Uri.parse('${SpotifyConfig.getTrackUrl}/$trackId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return song_model.Song.fromJson(data['track']);
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get recommendations - COMPLETELY SECURE
  static Future<List<song_model.Song>> getRecommendations({String? seedTracks, String? seedArtists, int limit = 10}) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (seedTracks != null) params['seed_tracks'] = seedTracks;
      if (seedArtists != null) params['seed_artists'] = seedArtists;
      
      final url = Uri.parse(SpotifyConfig.getRecommendationsUrl).replace(queryParameters: params);
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => song_model.Song.fromJson(trackData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  // NEW: Batch process multiple artists at once
static Future<List<Map<String, dynamic>>> getBatchArtistsData(List<String> artistNames) async {
  try {
    final url = Uri.parse('${SpotifyConfig.baseUrl}/api/artists/batch');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'artistNames': artistNames
      }),
    );
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['artists']);
      } else {
        throw Exception('Backend error: ${data['error']}');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Batch artists error: $e');
    // Return empty results for all artists
    return artistNames.map((name) => {
      'localName': name,
      'spotifyArtist': null
    }).toList();
  }
}
  // NEW: Enhance local songs with Spotify metadata
  static Future<List<Map<String, dynamic>>> enhanceLocalSongsMetadata(List<LocalSong> localSongs) async {
    try {
      final response = await http.post(
        Uri.parse(SpotifyConfig.enhanceLocalMetadataUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'songs': localSongs.map((song) => {
            'id': song.id,
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
            'duration': song.duration,
          }).toList()
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['enhancedSongs']);
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // NEW: Get artists data from local artist names
  static Future<List<Map<String, dynamic>>> getArtistsDataFromLocal(List<String> artistNames) async {
    try {
      final namesParam = artistNames.join(',');
      final url = Uri.parse('${SpotifyConfig.getArtistsFromLocalUrl}?artistNames=$namesParam');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['artists']);
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}