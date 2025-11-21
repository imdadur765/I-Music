import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/local_song_model.dart';

class LocalSongsService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // Performance optimizations
  List<LocalSong>? _cachedAllSongs;
  DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10); // Cache for 10 minutes
  
  final Map<String, List<LocalSong>> _artistSongsCache = {};
  final Map<String, Uint8List?> _albumArtCache = {};
  
  // Get all local songs from native MediaStore with caching
  Future<List<LocalSong>> getAllSongs() async {
    // Return cached data if available and not expired
    if (_cachedAllSongs != null && 
        _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      if (kDebugMode) {
        print('🎵 Returning cached songs: ${_cachedAllSongs!.length}');
      }
      return _cachedAllSongs!;
    }

    try {
      if (kDebugMode) {
        print('🔄 Fetching fresh songs from MediaStore...');
      }
      
      // Check permissions first
      final permissions = await checkPermissions();
      if (!permissions['hasStoragePermission']!) {
        if (kDebugMode) {
          print('❌ No storage permission');
        }
        _cachedAllSongs = _getDemoSongs();
        _lastCacheTime = DateTime.now();
        return _cachedAllSongs!;
      }

      final stopwatch = Stopwatch()..start();
      final List<dynamic> songsData = await _channel.invokeMethod('getAllSongs');
      stopwatch.stop();
      
      if (kDebugMode) {
        print('⏱️ MediaStore fetch took ${stopwatch.elapsedMilliseconds}ms');
      }
      
      _cachedAllSongs = songsData.map((data) {
        final map = Map<String, dynamic>.from(data);
        return LocalSong(
          id: map['id'].toString(),
          title: map['title'] ?? 'Unknown Title',
          album: map['album'] ?? 'Unknown Album',
          artist: map['artist'] ?? 'Unknown Artist',
          path: map['filePath'] ?? '',
          duration: (map['duration'] ?? 0).toInt(),
          size: (map['fileSize'] ?? 0).toInt(),
          albumId: map['albumId']?.toString() ?? '',
          uri: map['uri'] ?? '',
        );
      }).toList();

      _lastCacheTime = DateTime.now();
      
      if (kDebugMode) {
        print('✅ Loaded ${_cachedAllSongs!.length} songs');
      }
      
      return _cachedAllSongs!;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting local songs from native: $e');
      }
      _cachedAllSongs = _getDemoSongs();
      _lastCacheTime = DateTime.now();
      return _cachedAllSongs!;
    }
  }
  
  // Get album art from native side with caching
  Future<Uint8List?> getAlbumArt(String songId, String title, String artist) async {
    final cacheKey = '$songId-$title-$artist';
    
    // Return cached album art if available
    if (_albumArtCache.containsKey(cacheKey)) {
      return _albumArtCache[cacheKey];
    }
    
    try {
      final result = await _channel.invokeMethod('getAlbumArt', {
        'songId': int.tryParse(songId),
        'title': title,
        'artist': artist,
      });
      
      _albumArtCache[cacheKey] = result as Uint8List?;
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting album art: $e');
      }
      _albumArtCache[cacheKey] = null;
      return null;
    }
  }
  
  // Check permissions
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return Map<String, bool>.from(result);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking permissions: $e');
      }
      return {'hasStoragePermission': false, 'hasAudioPermission': false};
    }
  }
  
  // Request permissions
  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting permissions: $e');
      }
    }
  }
  
  // FAST: Get songs by specific artist using cached data
  Future<List<LocalSong>> getSongsByArtist(String artistName) async {
    // Check cache first
    if (_artistSongsCache.containsKey(artistName)) {
      return _artistSongsCache[artistName]!;
    }
    
    final allSongs = await getAllSongs();
    final artistSongs = allSongs.where((song) => 
      song.artist.toLowerCase().contains(artistName.toLowerCase())
    ).toList();
    
    // Cache the result
    _artistSongsCache[artistName] = artistSongs;
    
    return artistSongs;
  }
  
  // FAST: Get unique artists from local songs using cached data
  Future<List<String>> getUniqueArtists() async {
    final allSongs = await getAllSongs();
    final artistSet = <String>{};
    
    for (final song in allSongs) {
      final artist = song.artist;
      if (artist != 'Unknown Artist' && artist.isNotEmpty) {
        artistSet.add(artist);
      }
    }
    
    return artistSet.toList();
  }
  
  // FAST: Get all unique artists with their song counts
  Future<Map<String, int>> getArtistsWithSongCounts() async {
    final allSongs = await getAllSongs();
    final artistCounts = <String, int>{};
    
    for (final song in allSongs) {
      final artist = song.artist;
      if (artist != 'Unknown Artist' && artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }
    }
    
    return artistCounts;
  }
  
  // Clear cache (call this when songs are added/removed)
  void clearCache() {
    _cachedAllSongs = null;
    _lastCacheTime = null;
    _artistSongsCache.clear();
    _albumArtCache.clear();
    
    if (kDebugMode) {
      print('🗑️ Cleared LocalSongsService cache');
    }
  }
  
  // Preload data in background
  Future<void> preloadData() async {
    try {
      await getAllSongs();
      if (kDebugMode) {
        print('📥 Preloaded songs data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Preload failed: $e');
      }
    }
  }
  
  // Demo data as fallback
  List<LocalSong> _getDemoSongs() {
    return [
      LocalSong(
        id: '1',
        title: 'Tum Hi Ho',
        album: 'Aashiqui 2',
        artist: 'Arijit Singh',
        path: '/storage/emulated/0/Music/tum_hi_ho.mp3',
        duration: 262000,
        size: 5242880,
        albumId: '1',
        uri: 'content://media/external/audio/media/1',
      ),
      LocalSong(
        id: '2',
        title: 'Blinding Lights',
        album: 'After Hours', 
        artist: 'The Weeknd',
        path: '/storage/emulated/0/Music/blinding_lights.mp3',
        duration: 200000,
        size: 4000000,
        albumId: '2',
        uri: 'content://media/external/audio/media/2',
      ),
      LocalSong(
        id: '3',
        title: 'Love Story',
        album: 'Fearless',
        artist: 'Taylor Swift',
        path: '/storage/emulated/0/Music/love_story.mp3',
        duration: 235000,
        size: 4700000,
        albumId: '3',
        uri: 'content://media/external/audio/media/3',
      ),
    ];
  }
}