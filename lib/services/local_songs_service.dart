import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/local_song_model.dart';

class LocalSongsService {
  static const MethodChannel _channel = MethodChannel('i_music/media_store');
  
  // Get all local songs from native MediaStore
  Future<List<LocalSong>> getAllLocalSongs() async {
    try {
      // Check permissions first
      final permissions = await checkPermissions();
      if (!permissions['hasStoragePermission']!) {
        if (kDebugMode) {
          print('❌ No storage permission');
        }
        return _getDemoSongs();
      }

      final List<dynamic> songsData = await _channel.invokeMethod('getAllSongs');
      
      return songsData.map((data) {
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
    } catch (e) {
      if (kDebugMode) {
        print('Error getting local songs from native: $e');
      }
      return _getDemoSongs();
    }
  }
  
  // Get album art from native side
  Future<Uint8List?> getAlbumArt(String songId, String title, String artist) async {
    try {
      final result = await _channel.invokeMethod('getAlbumArt', {
        'songId': int.tryParse(songId),
        'title': title,
        'artist': artist,
      });
      return result as Uint8List?;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting album art: $e');
      }
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
        print('Error checking permissions: $e');
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
        print('Error requesting permissions: $e');
      }
    }
  }
  
  // Get songs by specific artist
  Future<List<LocalSong>> getSongsByArtist(String artistName) async {
    final allSongs = await getAllLocalSongs();
    return allSongs.where((song) => 
      song.artist.toLowerCase().contains(artistName.toLowerCase())
    ).toList();
  }
  
  // Get unique artists from local songs
  Future<List<String>> getUniqueArtists() async {
    final allSongs = await getAllLocalSongs();
    final artistSet = <String>{};
    
    for (final song in allSongs) {
      final artist = song.artist;
      if (artist != 'Unknown Artist' && artist.isNotEmpty) {
        artistSet.add(artist);
      }
    }
    
    return artistSet.toList();
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