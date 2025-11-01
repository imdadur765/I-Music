// lib/services/background_audio_service.dart - COMPLETELY FIXED WITH NOTIFICATION SUPPORT
import 'dart:io';
import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart'; // ✅ Single import for everything
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
          mediaItem.value = currentMediaItem.copyWith(duration: duration);
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

  void _handleTrackCompletion() {
    if (_currentIndex < _currentQueue.length - 1) {
      skipToNext();
    } else {
      _player.stop();
      _updatePlaybackState(_player.playbackEvent);
    }
  }

  void _updateCurrentMediaItem() async {
    if (_currentIndex < _currentQueue.length && !mediaItem.isClosed) {
      final mediaItemValue = await _songToMediaItem(_currentQueue[_currentIndex]);
      mediaItem.value = mediaItemValue;
    }
  }

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

      case 'debugNotificationArt':
        debugPrint('🔍 Debugging notification art');
        await _debugNotificationArt();
        return 'debug_completed';
      
      default:
        debugPrint('❌ Unknown custom action: $name');
        return null;
    }
  }

  Future<void> _forceCleanup() async {
    if (_isDisposed) return;
    
    debugPrint('🧹 FORCE CLEANUP - Stopping everything');
    try {
      await _player.stop();
      await _player.dispose();
      
      _currentQueue.clear();
      _currentIndex = 0;
      _albumArtCache.clear();
      
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

      final currentMediaItem = await _songToMediaItem(song);
      debugPrint('🎵 MediaItem artUri: ${currentMediaItem.artUri}');
      
      if (!mediaItem.isClosed) mediaItem.value = currentMediaItem;

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

  Future<void> _executeFallbackPlayback(Song song) async {
    try {
      debugPrint('🔄 Executing fallback playback for: ${song.title}');
      await _safeStopPlayer();
      await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri)), preload: true);
      
      final mediaItemValue = await _songToMediaItem(song);
      if (!mediaItem.isClosed) mediaItem.value = mediaItemValue;
      
      await _player.play();
      debugPrint('✅ Fallback playback successful');
    } catch (fallbackError) {
      debugPrint('❌ Fallback playback failed: $fallbackError');
    }
  }

  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      Uri? artUri = await _getNotificationArtUri(song);

      if (artUri == null) {
        debugPrint('⚠️ No artUri found, using default placeholder');
        artUri = await _generatePlaceholderArt(song);
      }

      final mediaItem = MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: artUri,
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

      debugPrint('🎵 MediaItem created with artUri: ${mediaItem.artUri}');
      return mediaItem;
    } catch (e) {
      debugPrint('❌ Error creating MediaItem: $e');
      final placeholderUri = await _generatePlaceholderArt(song);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: placeholderUri,
        extras: {
          'uri': song.uri,
          'song_object': song,
        },
      );
    }
  }

  Future<Uri?> _getNotificationArtUri(Song song) async {
    try {
      debugPrint('🔔 Getting notification art for: ${song.title}');
      
      if (_albumArtCache.containsKey(song.id)) {
        final cachedUri = _albumArtCache[song.id];
        debugPrint('✅ Using cached artUri for notification: $cachedUri');
        return Uri.parse(cachedUri!);
      }

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

      debugPrint('🔄 Extracting album art for notification...');
      final albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      debugPrint('🎨 AlbumArtService returned: ${albumArtBytes?.length ?? 0} bytes');
      
      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/notif_${song.mediaStoreId}.jpg');
        await file.writeAsBytes(albumArtBytes);
        
        final uri = Uri.file(file.path);
        debugPrint('✅ Notification art file created: ${file.path}');
        
        _albumArtCache[song.id] = uri.toString();
        return uri;
      }

      debugPrint('⚠️ No album art found for notification');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting notification art URI: $e');
      return null;
    }
  }

  // ✅ SIMPLIFIED: Generate placeholder art without HSL complications
  Future<Uri> _generatePlaceholderArt(Song song) async {
    try {
      debugPrint('🎨 Generating placeholder art for: ${song.title}');
      
      const size = 512;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);
      
      // ✅ SIMPLE COLOR: Use hash to generate a color without HSL
      final hash = song.title.hashCode;
      final colorValue = (hash & 0xFFFFFF) | 0xFF000000; // Ensure opacity
      final backgroundColor = ui.Color(colorValue);
      
      // Draw background
      final backgroundPaint = ui.Paint()..color = backgroundColor;
      canvas.drawRect(ui.Rect.fromLTRB(0, 0, size.toDouble(), size.toDouble()), backgroundPaint);
      
      // Draw music note icon with contrasting color
      final textColor = backgroundColor.computeLuminance() > 0.5 ? ui.Color(0xFF000000) : ui.Color(0xFFFFFFFF);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🎵',
          style: TextStyle(
            fontSize: 180,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
      
      // Convert to image
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/placeholder_${song.id}.jpg');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        
        debugPrint('✅ Placeholder art generated: ${file.path}');
        return Uri.file(file.path);
      }
      
      throw Exception('Failed to generate placeholder art');
    } catch (e) {
      debugPrint('❌ Error generating placeholder art: $e');
      return Uri.parse('https://via.placeholder.com/512/3366FF/FFFFFF?text=Music');
    }
  }

  Future<void> _debugNotificationArt() async {
    try {
      final current = currentSong;
      if (current != null) {
        debugPrint('🔍 DEBUG: Testing notification art for: ${current.title}');
        
        final artUri = await _getNotificationArtUri(current);
        debugPrint('🔍 DEBUG: Final artUri: $artUri');
        
        if (artUri != null) {
          final newMediaItem = await _songToMediaItem(current);
          mediaItem.value = newMediaItem;
          debugPrint('✅ DEBUG: MediaItem updated with artUri');
        } else {
          debugPrint('❌ DEBUG: No artUri available');
        }
      } else {
        debugPrint('❌ DEBUG: No current song playing');
      }
    } catch (e) {
      debugPrint('❌ DEBUG Error: $e');
    }
  }

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