import 'dart:math';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
class AppConstants {
  // ===============================
  // 🏷️ APP INFO & IDENTIFICATION
  // ===============================
  static const String appName = 'i_music';
  static const String appVersion = '1.0.0';
  static const String appPackage = 'com.example.i_music';
  
  // ===============================
  // 🗄️ STORAGE & DATABASE
  // ===============================
  static const String favoritesBox = 'favorites';
  static const String playlistsBox = 'playlists';
  static const String recentlyPlayedBox = 'recently_played';
  static const String settingsBox = 'app_settings';
  static const String audioStateBox = 'audio_state';
  
  // ===============================
  // 🎵 AUDIO SERVICE & BACKGROUND
  // ===============================
  static const String audioChannelId = 'com.imusic.channel.audio';
  static const String audioChannelName = 'i_music Audio Playback';
  static const String mediaBrowserService = 'android.media.browse.MediaBrowserService';
  
  // Audio focus and behavior
  static const String audioSessionCategory = 'playback';
  static const List<String> audioSessionOptions = [
    'allowBluetooth',
    'allowBluetoothA2DP', 
    'allowAirPlay',
    'mixWithOthers',
  ];
  
  // ===============================
  // 🎨 UI & THEMING
  // ===============================
  static const Color primaryColor = Color(0xFF6B35FF);
  static const Color accentColor = Color(0xFF8E53FF);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color onSurfaceColor = Color(0xFFFFFFFF);
  
  // Player screen colors
  static const Color playerBackgroundStart = Color(0xFF6B35FF);
  static const Color playerBackgroundEnd = Color(0xFF121212);
  
  // ===============================
  // 📱 METHOD CHANNELS
  // ===============================
  static const String mediaStoreChannel = 'i_music/media_store';
  static const String audioServiceChannel = 'com.ryanheise.audioservice';
  
  // ===============================
  // 🔐 PERMISSIONS
  // ===============================
  static const List<String> requiredPermissions = [
    'storage',
    'audio', 
    'notification',
    'manageExternalStorage',
  ];
  
  static const Map<String, String> permissionDescriptions = {
    'storage': 'Access your music files',
    'audio': 'Play audio in background',
    'notification': 'Show playback controls',
    'manageExternalStorage': 'Manage music files on newer Android versions',
  };
  
  // ===============================
  // 🎼 AUDIO CONFIGURATION
  // ===============================
  static const List<String> supportedAudioFormats = [
    'mp3',
    'aac',
    'ogg',
    'wav',
    'm4a',
    'flac',
  ];
  
  static const double defaultVolume = 1.0;
  static const double defaultSpeed = 1.0;
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  
  // ===============================
  // ⏱️ TIMING & DURATIONS
  // ===============================
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDuration = Duration(milliseconds: 500);
  static const Duration splashDelay = Duration(seconds: 2);
  static const Duration preloadDelay = Duration(milliseconds: 100);
  
  // ===============================
  // 📊 PLAYBACK SETTINGS
  // ===============================
  static const int minSongDuration = 10000; // 10 seconds
  static const int maxRecentlyPlayed = 50;
  static const int searchDebounceMs = 300;
  
  // ===============================
  // 🎯 ERROR MESSAGES
  // ===============================
  static const String permissionError = 'Storage permission required to access music files';
  static const String audioError = 'Unable to play audio file';
  static const String networkError = 'Network connection required';
  static const String unknownError = 'An unexpected error occurred';
  
  // ===============================
  // 🎨 ANIMATION PATHS
  // ===============================
  static const String splashAnimation = 'assets/animations/splash_music.json';
  static const String emptyAnimation = 'assets/animations/empty_list.json';
  static const String loadingAnimation = 'assets/animations/loading_music.json';
  static const String errorAnimation = 'assets/animations/error_state.json';
  
  // ===============================
  // 📁 FILE PATHS & URLS
  // ===============================
  static const String defaultAlbumArt = 'assets/images/default_album_art.png';
  static const String appIcon = 'mipmap/ic_launcher';
  static const String notificationIcon = 'mipmap/ic_launcher';
  
  // ===============================
  // 🔧 FEATURE TOGGLES
  // ===============================
  static const bool enableBackgroundAudio = true;
  static const bool enableNotificationControls = true;
  static const bool enablePreload = true;
  static const bool enableSearch = true;
  static const bool enableFavorites = true;
  static const bool enableRecentlyPlayed = true;
  
  // ===============================
  // 📝 TEXT & LABELS
  // ===============================
  static const String nowPlayingTitle = 'Now Playing';
  static const String allSongsTitle = 'All Songs';
  static const String favoritesTitle = 'Favorites';
  static const String playlistsTitle = 'Playlists';
  static const String recentlyPlayedTitle = 'Recently Played';
  
  // ===============================
  // 🎵 DEFAULT VALUES
  // ===============================
  static const String unknownArtist = 'Unknown Artist';
  static const String unknownAlbum = 'Unknown Album';
  static const String unknownTitle = 'Unknown Title';
  static const String unknownGenre = 'Unknown Genre';
  
  // ===============================
  // 🛠️ UTILITY METHODS
  // ===============================
  
  /// Format duration from milliseconds to HH:MM:SS or MM:SS
  static String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
  
  /// Format file size to human readable format
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
  
  /// Check if audio format is supported
  static bool isSupportedFormat(String uri) {
    final extension = uri.split('.').last.toLowerCase();
    return supportedAudioFormats.contains(extension);
  }
  
  /// Get default fallback song for error states
  static Map<String, dynamic> get fallbackSong => {
    'id': 'fallback_${DateTime.now().microsecondsSinceEpoch}',
    'title': 'No songs available',
    'artist': 'Check permissions and storage',
    'album': 'i_music',
    'duration': 0,
    'uri': '',
    'albumArt': null,
  };
  
  /// Validate song for playback
  static bool isValidSong(Song song) {
    return song.uri.isNotEmpty && 
           song.duration >= minSongDuration &&
           isSupportedFormat(song.uri);
  }
  
  /// Get shuffle mode string
  static String getShuffleModeString(bool isShuffling) {
    return isShuffling ? 'Shuffle: On' : 'Shuffle: Off';
  }
  
  /// Get repeat mode string
  static String getRepeatModeString(int repeatMode) {
    switch (repeatMode) {
      case 1: return 'Repeat: One';
      case 2: return 'Repeat: All';
      default: return 'Repeat: Off';
    }
  }
  
  /// Get audio session configuration for different platforms
  static Map<String, dynamic> getAudioSessionConfig() {
    return {
      'android': {
        'contentType': 'music',
        'usage': 'media',
        'audioFocus': 'gain',
      },
      'ios': {
        'category': audioSessionCategory,
        'options': audioSessionOptions,
      },
    };
  }
}

// ===============================
// 🎵 SONG MODEL EXTENSIONS
// ===============================

extension SongExtensions on Song {
  /// Check if song is valid for playback
  bool get isValidForPlayback => AppConstants.isValidSong(this);
  
  /// Get formatted duration string
  String get formattedDuration => AppConstants.formatDuration(duration);
  
  /// Get file extension
  String get fileExtension {
    try {
      return uri.split('.').last.toLowerCase();
    } catch (e) {
      return 'mp3'; // Default assumption
    }
  }
}

// ===============================
// 🎛️ AUDIO SERVICE CONSTANTS
// ===============================

class AudioServiceConstants {
  // Audio service actions
  static const String actionPlay = 'com.imusic.action.PLAY';
  static const String actionPause = 'com.imusic.action.PAUSE';
  static const String actionStop = 'com.imusic.action.STOP';
  static const String actionSkipNext = 'com.imusic.action.SKIP_NEXT';
  static const String actionSkipPrevious = 'com.imusic.action.SKIP_PREVIOUS';
  static const String actionSeek = 'com.imusic.action.SEEK';
  
  // Notification actions
  static const List<int> androidCompactActions = [0, 1, 3];
  static const int notificationId = 1001;
  
  // Media session extras
  static const String extraSong = 'song';
  static const String extraQueue = 'queue';
  static const String extraPosition = 'position';
}

// ===============================
// 📱 PROVIDER KEYS
// ===============================

class ProviderKeys {
  static const String audioHandler = 'audio_handler';
  static const String songsList = 'songs_list';
  static const String currentSong = 'current_song';
  static const String playbackState = 'playback_state';
  static const String favorites = 'favorites';
  static const String playlists = 'playlists';
}

// ===============================
// 🗂️ DATABASE SCHEMA
// ===============================

class DatabaseSchema {
  static const int songTypeId = 0;
  static const int playlistTypeId = 1;
  
  static const Map<int, String> typeMapping = {
    songTypeId: 'Song',
    playlistTypeId: 'Playlist',
  };
}

// Import required dependencies