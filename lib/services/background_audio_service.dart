// lib/services/background_audio_service.dart - COMPLETELY FIXED
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';
import 'album_art_service.dart';

class BackgroundAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final List<Song> _currentQueue = [];
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // ✅ FIXED: Album art cache to prevent multiple file operations
  final Map<String, String> _albumArtCache = {};

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _setupAudioListeners();
      _isInitialized = true;
      debugPrint('✅ BackgroundAudioHandler initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundAudioHandler: $e');
    }
  }

  void _setupAudioListeners() {
    _player.playbackEventStream.listen(_updatePlaybackState);
    
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleTrackCompletion();
      }
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < _currentQueue.length) {
        _currentIndex = index;
        _updateCurrentMediaItem();
      }
    });

    _player.durationStream.listen((duration) {
      if (duration != null && !mediaItem.isClosed) {
        final currentMediaItem = mediaItem.value;
        if (currentMediaItem != null) {
          mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && state.playing) {
        debugPrint('❌ Player error - resetting to idle');
        _updatePlaybackState(_player.playbackEvent);
      }
    });
  }

  void _updatePlaybackState(PlaybackEvent event) {
    if (playbackState.isClosed || _isDisposed) return;
    
    try {
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _mapProcessingState(event.processingState),
        playing: _player.playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex ?? _currentIndex,
        updateTime: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('❌ Error in _updatePlaybackState: $e');
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ✅ FIXED: Missing method
  void _handleTrackCompletion() {
    if (_currentIndex < _currentQueue.length - 1) {
      skipToNext();
    } else {
      _player.stop();
      _updatePlaybackState(_player.playbackEvent);
    }
  }

  // ✅ FIXED: Album art ke saath media item update
  void _updateCurrentMediaItem() async {
    if (_currentIndex < _currentQueue.length && !mediaItem.isClosed) {
      final mediaItemValue = await _songToMediaItem(_currentQueue[_currentIndex]);
      mediaItem.add(mediaItemValue);
    }
  }

  // ✅ FIXED: Added @override annotation
  @override
  Future<dynamic> customAction(String name, [dynamic extras]) async {
    debugPrint('🎛️ Custom action received: $name');
    
    switch (name) {
      case 'stopFromNative':
        debugPrint('🛑 Stop command from native received');
        await _forceCleanup();
        return 'stopped';
      
      case 'dispose':
        debugPrint('🔥 Dispose command received');
        await dispose();
        return 'disposed';

      case 'clearAlbumArtCache':
        debugPrint('🖼️ Clearing album art cache');
        _albumArtCache.clear();
        return 'cache_cleared';
      
      default:
        debugPrint('❌ Unknown custom action: $name');
        return null;
    }
  }

  // ✅ NEW: Force cleanup method for swipe close
  Future<void> _forceCleanup() async {
    if (_isDisposed) return;
    
    debugPrint('🧹 FORCE CLEANUP - Stopping everything');
    try {
      // Stop player
      await _player.stop();
      
      // Dispose player completely
      await _player.dispose();
      
      // Clear all data
      _currentQueue.clear();
      _currentIndex = 0;
      _albumArtCache.clear();
      
      // Update state to idle
      if (!playbackState.isClosed) {
        playbackState.add(PlaybackState(
          controls: [],
          systemActions: const {MediaAction.stop},
          processingState: AudioProcessingState.idle,
          playing: false,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
          queueIndex: null,
        ));
      }
      
      _isDisposed = true;
      debugPrint('✅ FORCE CLEANUP COMPLETED - Ready for app death');
    } catch (e) {
      debugPrint('❌ Force cleanup error: $e');
    }
  }

  // ✅ FIXED: Album art integration with setSong
  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      debugPrint('🎵 Setting song: ${song.title}');
      debugPrint('🎵 MediaStore ID: ${song.mediaStoreId}');
      
      if (song.uri.isEmpty) throw ArgumentError('Song URI cannot be empty');
      if (queue.isEmpty) throw ArgumentError('Queue cannot be empty');

      final initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) throw ArgumentError('Target song not found in queue');

      _currentQueue..clear()..addAll(queue);
      _currentIndex = initialIndex;

      await _safeStopPlayer();

      // ✅ FIXED: Create MediaItem with album art
      final currentMediaItem = await _songToMediaItem(song);
      debugPrint('🎵 MediaItem artUri: ${currentMediaItem.artUri}');
      
      if (!mediaItem.isClosed) mediaItem.add(currentMediaItem);

      // Create audio sources
      final audioSources = queue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
      await _player.setAudioSources(audioSources, preload: true, initialIndex: initialIndex);

      await _player.setVolume(1.0);
      await _player.setSpeed(1.0);
      await _player.play();

      debugPrint('✅ Now playing: ${song.title}');
    } catch (e) {
      debugPrint('❌ Error setting song: $e');
      await _executeFallbackPlayback(song);
    }
  }

  Future<void> _safeStopPlayer() async {
    try {
      if (_player.processingState != ProcessingState.idle) {
        await _player.stop();
        await _player.seek(Duration.zero);
      }
    } catch (e) {
      debugPrint('⚠️ Warning during player stop: $e');
    }
  }

  // ✅ FIXED: Fallback playback with album art
  Future<void> _executeFallbackPlayback(Song song) async {
    try {
      debugPrint('🔄 Executing fallback playback for: ${song.title}');
      await _safeStopPlayer();
      await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri)), preload: true);
      
      // ✅ ADDED: MediaItem with album art for fallback
      final mediaItemValue = await _songToMediaItem(song);
      if (!mediaItem.isClosed) mediaItem.add(mediaItemValue);
      
      await _player.play();
      debugPrint('✅ Fallback playback successful');
    } catch (fallbackError) {
      debugPrint('❌ Fallback playback failed: $fallbackError');
    }
  }

  // ✅ FIXED: MediaItem creation with proper album art
  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      Uri? artUri;

      // Check cache first for performance
      if (_albumArtCache.containsKey(song.id)) {
        artUri = Uri.parse(_albumArtCache[song.id]!);
        debugPrint('🖼️ Using cached album art for: ${song.title}');
      } else {
        // Try to get album art
        artUri = await _getAlbumArtUri(song);
        if (artUri != null) {
          _albumArtCache[song.id] = artUri.toString();
        }
      }

      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: artUri, // ✅ This will show in notification/lock screen
        genre: song.genre,
        extras: {
          'uri': song.uri,
          'song_object': song,
          'album': song.album,
          'artist': song.artist,
          'albumArt': song.albumArt,
          'playCount': song.playCount,
          'isFavorite': song.isFavorite,
          'trackNumber': song.trackNumber,
          'year': song.year,
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating MediaItem: $e');
      // Return MediaItem without album art as fallback
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        extras: {
          'uri': song.uri,
          'song_object': song,
        },
      );
    }
  }

  // ✅ FIXED: Album art extraction method with NAMED parameters
  Future<Uri?> _getAlbumArtUri(Song song) async {
    try {
      debugPrint('🔄 Album art extraction started for: ${song.title}');
      
      // Method 1: Use existing albumArt path from song
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        if (song.albumArt!.startsWith('http')) {
          return Uri.parse(song.albumArt!);
        } else {
          final file = File(song.albumArt!);
          if (await file.exists()) {
            return Uri.file(song.albumArt!);
          }
        }
      }

      // Method 2: Extract from MediaStore using AlbumArtService
      // ✅ FIXED: Use NAMED parameters as required by AlbumArtService
      final albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,   // Named parameter
        songTitle: song.title,       // Named parameter
        artist: song.artist,         // Named parameter
      );

      debugPrint('🎨 AlbumArtService returned: ${albumArtBytes?.length ?? 0} bytes');
      
      if (albumArtBytes != null) {
        // Save to temporary file and return URI
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${song.id}_album_art.jpg');
        await file.writeAsBytes(albumArtBytes);
        
        final uri = Uri.file(file.path);
        debugPrint('✅ Album art file created: ${file.path}');
        debugPrint('✅ Final artUri for notification: $uri');
        
        // ✅ EXTRA CHECK: File exists and readable?
        final exists = await file.exists();
        debugPrint('✅ File exists: $exists');
        if (exists) {
          final length = await file.length();
          debugPrint('✅ File size: $length bytes');
        }
        
        return uri;
      }

      debugPrint('⚠️ No album art found for: ${song.title}');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting album art URI: $e');
      return null;
    }
  }

  // ✅ FIXED: Added @override annotations for all methods
  @override
  Future<void> play() async {
    try {
      await _player.play();
      debugPrint('▶️ Play command executed');
    } catch (e) {
      debugPrint('❌ Error in play: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      debugPrint('⏸️ Pause command executed');
    } catch (e) {
      debugPrint('❌ Error in pause: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      debugPrint('🔍 Seek to $position executed');
    } catch (e) {
      debugPrint('❌ Error in seek: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_currentIndex < _currentQueue.length - 1) {
        await _player.seekToNext();
        debugPrint('⏭️ Skip to next executed');
      } else {
        await stop();
        debugPrint('⏹️ End of queue - stopping');
      }
    } catch (e) {
      debugPrint('❌ Error in skipToNext: $e');
      if (_currentIndex + 1 < _currentQueue.length) {
        await setSong(_currentQueue[_currentIndex + 1], _currentQueue);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        debugPrint('🔁 Restarting current track');
      } else if (_currentIndex > 0) {
        await _player.seekToPrevious();
        debugPrint('⏮️ Skip to previous executed');
      }
    } catch (e) {
      debugPrint('❌ Error in skipToPrevious: $e');
      if (_currentIndex > 0) {
        await setSong(_currentQueue[_currentIndex - 1], _currentQueue);
      }
    }
  }

  // ✅ Other necessary methods
  @override
  Future<void> stop() async {
    debugPrint('🛑 STOP CALLED - Preparing for app termination');
    await _forceCleanup();
    return super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    debugPrint('🔴 onTaskRemoved CALLED - App being killed by system');
    await _forceCleanup();
    await super.onTaskRemoved();
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      final clampedSpeed = speed.clamp(0.5, 2.0);
      await _player.setSpeed(clampedSpeed);
      debugPrint('🎛️ Speed set to $clampedSpeed');
    } catch (e) {
      debugPrint('❌ Error setting speed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      debugPrint('🔊 Volume set to $clampedVolume');
    } catch (e) {
      debugPrint('❌ Error setting volume: $e');
    }
  }

  // ✅ Getters
  List<Song> get currentQueue => List.unmodifiable(_currentQueue);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex < _currentQueue.length ? _currentQueue[_currentIndex] : null;
  Duration? get duration => _player.duration;
  Duration get position => _player.position;

  // ✅ Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('🔥 DISPOSE CALLED - Final cleanup');
    _albumArtCache.clear();
    await _forceCleanup();
  }
}