import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/spotify_config.dart';
import '../models/artist_model.dart';

class SpotifyService {
  static const String _baseUrl = 'https://api.spotify.com/v1';
  static const String _authUrl = 'https://accounts.spotify.com/api/token';
  
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Get access token using Client Credentials Flow
  Future<void> _getAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${SpotifyConfig.clientId}:${SpotifyConfig.clientSecret}'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));
        print('✅ Spotify Access Token Received');
      } else {
        throw Exception('Failed to get token: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Spotify Auth Error: $e');
    }
  }

  // Ensure we have a valid token
  Future<void> _ensureToken() async {
    if (_accessToken == null || 
        _tokenExpiry == null || 
        _tokenExpiry!.isBefore(DateTime.now())) {
      await _getAccessToken();
    }
  }

  // ✅ ENSURE: This method returns List<Artist> from our single model
  Future<List<Artist>> searchArtists(String query, {int limit = 20}) async {
    await _ensureToken();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search').replace(
          queryParameters: {
            'q': query,
            'type': 'artist',
            'limit': limit.toString(),
          },
        ),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> artistsData = data['artists']['items'];
        
        // ✅ ENSURE: Using Artist.fromSpotifyJson() consistently
        return artistsData.map((artistData) => Artist.fromSpotifyJson(artistData)).toList();
      } else {
        print('❌ Spotify API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Search artists error: $e');
      rethrow;
    }
  }

  // ✅ ENSURE: This method returns Artist from our single model
  Future<Artist> getArtist(String artistId) async {
    await _ensureToken();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/artists/$artistId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // ✅ ENSURE: Using Artist.fromSpotifyJson() consistently
        return Artist.fromSpotifyJson(data);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get artist error: $e');
      rethrow;
    }
  }

  // Get artist's top tracks
  Future<List<Song>> getArtistTopTracks(String artistId) async {
    await _ensureToken();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/artists/$artistId/top-tracks').replace(
          queryParameters: {'market': 'IN'}, // India market
        ),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return _parseTracks(data['tracks']);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get top tracks error: $e');
      rethrow;
    }
  }

  // Parse tracks from response
  List<Song> _parseTracks(List<dynamic> tracksData) {
    return tracksData.map((trackData) {
      return Song(
        id: trackData['id'] ?? '',
        title: trackData['name'] ?? 'Unknown Track',
        duration: _formatDuration(trackData['duration_ms'] ?? 0),
        artist: trackData['artists']?.isNotEmpty == true 
            ? trackData['artists'][0]['name'] 
            : 'Unknown Artist',
        albumArt: _getBestImage(trackData['album']?['images']),
        previewUrl: trackData['preview_url'],
        popularity: trackData['popularity'] ?? 0,
        album: trackData['album']?['name'] ?? '',
      );
    }).toList();
  }

  // Helper methods
  String _getBestImage(List<dynamic>? images) {
    if (images == null || images.isEmpty) return '';
    
    // Prefer medium size (300x300), fallback to smallest
    for (final image in images) {
      if (image['height'] == 300 || image['width'] == 300) {
        return image['url'];
      }
    }
    
    return images.isNotEmpty ? images.first['url'] : '';
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}