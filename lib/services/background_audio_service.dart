// lib/services/background_audio_service.dart - COMPLETELY FIXED
import 'dart:io';
import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import '../models/song_model.dart';
import 'album_art_service.dart';

class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final List<Song> _currentQueue = [];
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;

  final Map<String, String> _albumArtCache = {};

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _initializePlayer();
  }

  // ✅ FIXED: Streams with correct return types
  Stream<Duration> get durationStream => _player.durationStream.where((duration) => duration != null).cast<Duration>();
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  
  // ✅ FIXED: Return ProcessingState instead of AudioProcessingState
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  
  // ✅ FIXED: Add playerStateStream
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ✅ FIXED: Getters without @override
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }
  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
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

  // ✅ FIXED: YAHAN MAJOR CHANGES KIYE HAIN - DIRECT FILE URI USE KARO
  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      // ✅ DIRECT ALBUM ART FETCH KARO
      Uint8List? albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      Uri? artUri;
      
      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        debugPrint('🎨 Album art found: ${albumArtBytes.length} bytes');
        
        // ✅ DIRECT TEMP FILE BANAO AUR FILE URI USE KARO
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/album_art_${song.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(albumArtBytes);
        
        artUri = Uri.file(tempFile.path);
        debugPrint('📁 Album art saved to: ${tempFile.path}');
        
        // ✅ CACHE MEIN STORE KARO
        _albumArtCache[song.id] = tempFile.path;
      } else {
        debugPrint('⚠️ No album art found, using placeholder');
        artUri = await _generatePlaceholderArt(song);
      }

      // ✅ SIMPLE EXTRAS - COMPLEX METADATA HATA DIYA
      final extras = <String, dynamic>{
        'uri': song.uri,
        'album': song.album,
        'artist': song.artist,
        'mediaStoreId': song.mediaStoreId,
        // ✅ ONLY NECESSARY METADATA
        'android.media.metadata.ALBUM_ART_URI': artUri.toString(),
      };

      final mediaItem = MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: artUri,
        genre: song.genre,
        extras: extras,
      );

      debugPrint('🎵 MediaItem created with artUri: $artUri');
      
      return mediaItem;
    } catch (e) {
      debugPrint('❌ Error creating MediaItem: $e');
      // ✅ SIMPLE FALLBACK
      final placeholderUri = await _generatePlaceholderArt(song);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: placeholderUri,
      );
    }
  }

  // ✅ FIXED: SIMPLIFIED NOTIFICATION ART URI
  Future<Uri?> _getNotificationArtUri(Song song) async {
    try {
      debugPrint('🔔 Getting notification art for: ${song.title}');

      // ✅ CHECK CACHE FIRST
      if (_albumArtCache.containsKey(song.id)) {
        final cachedPath = _albumArtCache[song.id];
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            debugPrint('✅ Using cached album art: $cachedPath');
            return Uri.file(cachedPath);
          }
        }
      }

      // ✅ DIRECT ALBUM ART FETCH
      final albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        debugPrint('🎨 Extracted ${albumArtBytes.length} bytes of album art');
        
        // ✅ SAVE TO TEMP FILE
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/notif_${song.id}.jpg');
        await tempFile.writeAsBytes(albumArtBytes);
        
        _albumArtCache[song.id] = tempFile.path;
        debugPrint('✅ Album art saved to: ${tempFile.path}');
        
        return Uri.file(tempFile.path);
      }

      debugPrint('❌ No album art available');
      return null;

    } catch (e) {
      debugPrint('❌ Error in _getNotificationArtUri: $e');
      return null;
    }
  }

  // ✅ FIXED: SIMPLIFIED PLACEHOLDER ART
  Future<Uri> _generatePlaceholderArt(Song song) async {
    try {
      debugPrint('🎨 Generating placeholder art for: ${song.title}');

      const size = 512;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);

      // ✅ SIMPLE BACKGROUND COLOR
      final hash = song.title.hashCode;
      final colorValue = (hash & 0xFFFFFF) | 0xFF000000;
      final backgroundColor = ui.Color(colorValue);

      final backgroundPaint = ui.Paint()..color = backgroundColor;
      canvas.drawRect(ui.Rect.fromLTRB(0, 0, size.toDouble(), size.toDouble()), backgroundPaint);

      // ✅ SIMPLE TEXT
      final textPainter = TextPainter(
        text: TextSpan(
          text: song.title.isNotEmpty ? song.title[0].toUpperCase() : 'M',
          style: const TextStyle(
            fontSize: 180,
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
      // ✅ ULTIMATE FALLBACK
      return Uri.parse('file:///android_asset/placeholder_art.png');
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
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_currentIndex > 0) {
        await _player.seekToPrevious();
        debugPrint('⏮️ Skip to previous executed');
      } else {
        await _player.seek(Duration.zero);
        debugPrint('🔁 Reset to start');
      }
    } catch (e) {
      debugPrint('❌ Error in skipToPrevious: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      debugPrint('⏹️ Stop command executed');
    } catch (e) {
      debugPrint('❌ Error in stop: $e');
    }
  }

  // ✅ FIXED: Dispose method
  Future<void> dispose() async {
    _isDisposed = true;
    await _player.dispose();
    debugPrint('🔥 BackgroundAudioHandler disposed');
  }

  // Helper getter for current song
  Song? get currentSong {
    if (_currentIndex < _currentQueue.length) {
      return _currentQueue[_currentIndex];
    }
    return null;
  }
}