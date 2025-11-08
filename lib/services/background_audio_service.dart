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

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _initializePlayer();
  }

  // Streams
  Stream<Duration> get durationStream => _player.durationStream.where((duration) => duration != null).cast<Duration>();
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
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
      debugPrint('✅ BackgroundAudioHandler initialized');
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
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
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

  void _updateCurrentMediaItem() {
    if (_currentIndex < _currentQueue.length && !mediaItem.isClosed) {
      _songToMediaItem(_currentQueue[_currentIndex]).then((mediaItemValue) {
        mediaItem.value = mediaItemValue;
      });
    }
  }

  // ✅ FIXED: PROPER FILEPROVIDER URI GENERATION
  Future<Uri?> _getAlbumArtUri(File artFile, Song song) async {
    try {
      debugPrint('🎨 Generating secure album art URI...');
      
      if (!await artFile.exists()) {
        debugPrint('❌ Album art file does not exist: ${artFile.path}');
        return null;
      }

      final fileName = 'album_art_${song.mediaStoreId}.jpg';
      
      // ✅ SOLUTION 1: Use FileProvider content URI (Recommended)
      final contentUri = 'content://com.example.i_music.fileprovider/music_files/$fileName';
      debugPrint('✅ Generated content URI: $contentUri');
      
      // Copy file to Music directory for FileProvider access
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final musicDir = Directory('${externalDir.path}/Music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        
        final publicFile = File('${musicDir.path}/$fileName');
        final bytes = await artFile.readAsBytes();
        await publicFile.writeAsBytes(bytes);
        
        debugPrint('✅ Album art prepared for FileProvider: ${publicFile.path}');
        return Uri.parse(contentUri);
      }

      // ✅ SOLUTION 2: Fallback to cache directory with FileProvider
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/$fileName');
      final bytes = await artFile.readAsBytes();
      await cacheFile.writeAsBytes(bytes);
      
      final cacheUri = 'content://com.example.i_music.fileprovider/cache/$fileName';
      debugPrint('✅ Using cache URI: $cacheUri');
      return Uri.parse(cacheUri);

    } catch (e) {
      debugPrint('❌ Error in _getAlbumArtUri: $e');
      
      // ✅ EMERGENCY: Use online image as last resort
      return Uri.parse('https://raw.githubusercontent.com/flutter/website/main/src/assets/images/docs/owl.jpg');
    }
  }

  // ✅ FIXED: MediaItem creation with FileProvider URIs
  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      debugPrint('🎵 Creating MediaItem for: ${song.title}');
      
      Uint8List? albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      Uri? artUri;

      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        debugPrint('🎨 Album art found: ${albumArtBytes.length} bytes');

        // Save to temporary file first
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_album_art_${song.mediaStoreId}.jpg');
        await tempFile.writeAsBytes(albumArtBytes);

        // Generate FileProvider URI
        artUri = await _getAlbumArtUri(tempFile, song);
        
        debugPrint('✅ Final artUri for MediaItem: $artUri');
      } else {
        debugPrint('⚠️ No album art found, generating placeholder');
        artUri = await _generatePlaceholderArt(song);
      }

      final mediaItem = MediaItem(
        id: song.mediaStoreId.toString(),
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        artUri: artUri,
        genre: song.genre,
        displayTitle: song.title,
        displaySubtitle: song.artist,
        displayDescription: song.album,
        extras: {
          'uri': song.uri,
          'mediaStoreId': song.mediaStoreId.toString(),
          // Android standard metadata for OxygenOS
          'android.media.metadata.TITLE': song.title,
          'android.media.metadata.ARTIST': song.artist,
          'android.media.metadata.ALBUM': song.album ?? 'Unknown Album',
          'android.media.metadata.DURATION': song.duration,
          if (artUri != null) 'android.media.metadata.ALBUM_ART_URI': artUri.toString(),
          // OxygenOS specific
          'content_type': 'audio',
          'playback_type': 'music',
        },
      );

      debugPrint('🎵 MediaItem created successfully with artUri: $artUri');
      return mediaItem;
      
    } catch (e) {
      debugPrint('❌ Error creating MediaItem: $e');
      // Fallback without art
      return MediaItem(
        id: song.mediaStoreId.toString(),
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        extras: {
          'uri': song.uri,
          'mediaStoreId': song.mediaStoreId.toString(),
        },
      );
    }
  }

  Future<Uri> _generatePlaceholderArt(Song song) async {
    try {
      debugPrint('🎨 Generating placeholder art for: ${song.title}');

      const size = 512;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);

      // Background color based on song title hash
      final hash = song.title.hashCode;
      final backgroundColor = ui.Color.fromARGB(204, 
        (hash >> 16) & 0xFF, 
        (hash >> 8) & 0xFF, 
        hash & 0xFF
      );

      final backgroundPaint = ui.Paint()..color = backgroundColor;
      canvas.drawRect(ui.Rect.fromLTRB(0, 0, size.toDouble(), size.toDouble()), backgroundPaint);

      // Text
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
        final file = File('${tempDir.path}/placeholder_${song.mediaStoreId}.jpg');
        await file.writeAsBytes(byteData.buffer.asUint8List());

        // Generate FileProvider URI for placeholder too
        final publicUri = await _getAlbumArtUri(file, song);
        return publicUri ?? file.uri;
      }

      throw Exception('Failed to generate placeholder art');
    } catch (e) {
      debugPrint('❌ Error generating placeholder art: $e');
      // Emergency fallback
      return Uri.parse('https://picsum.photos/300/300');
    }
  }

  // ✅ ADDED: Volume control via custom action
  @override
  Future<dynamic> customAction(String name, [dynamic extras]) async {
    debugPrint('🎛️ Custom action: $name');

    switch (name) {
      case 'setVolume':
        final volume = extras['volume'] as double;
        await setVolume(volume);
        return 'volume_set';

      case 'testOxygenOS':
        debugPrint('🔧 Testing OxygenOS compatibility');
        _testOxygenOSCompatibility();
        return 'tested';

      case 'debugMediaSession':
        debugPrint('🔍 Debugging MediaSession');
        _debugMediaSession();
        return 'debugged';

      case 'forceCapsuleTest':
        debugPrint('🚀 Force testing OxygenOS capsule');
        await _forceCapsuleTest();
        return 'capsule_tested';

      default:
        return null;
    }
  }

  // ✅ ADDED: Force capsule test
  Future<void> _forceCapsuleTest() async {
    try {
      if (_currentIndex < _currentQueue.length) {
        final song = _currentQueue[_currentIndex];
        debugPrint('🎯 FORCE CAPSULE TEST - Song: ${song.title}');
        
        // Recreate MediaItem with force update
        final updatedMediaItem = await _songToMediaItem(song);
        if (!mediaItem.isClosed) {
          mediaItem.value = updatedMediaItem;
        }
        
        // Force playback state update
        _updatePlaybackState(_player.playbackEvent);
        
        // Double update for OxygenOS
        await Future.delayed(Duration(milliseconds: 100));
        _updatePlaybackState(_player.playbackEvent);
        
        debugPrint('✅ Force capsule test completed - Check now!');
      }
    } catch (e) {
      debugPrint('❌ Force capsule test failed: $e');
    }
  }

  void _testOxygenOSCompatibility() {
    try {
      debugPrint('🎯 Testing OxygenOS Capsule Compatibility...');
      
      if (_currentIndex < _currentQueue.length) {
        final song = _currentQueue[_currentIndex];
        debugPrint('🎵 Current Song: ${song.title}');
        debugPrint('🎵 MediaStore ID: ${song.mediaStoreId}');
        debugPrint('🎵 Player State: ${_player.playing ? "Playing" : "Paused"}');
        debugPrint('🎵 Art URI: ${mediaItem.value?.artUri}');
        
        // Force update everything
        _updateCurrentMediaItem();
        _updatePlaybackState(_player.playbackEvent);
        
        debugPrint('✅ OxygenOS test completed - Check capsule now!');
      } else {
        debugPrint('❌ No song currently playing for OxygenOS test');
      }
    } catch (e) {
      debugPrint('❌ OxygenOS test failed: $e');
    }
  }

  // ✅ ADDED: testMediaSession method for compatibility
  void testMediaSession() {
    _testOxygenOSCompatibility();
  }

  void _debugMediaSession() {
    try {
      debugPrint('🔍 MEDIA SESSION DEBUG INFO:');
      debugPrint('🎵 MediaItem: ${mediaItem.value}');
      debugPrint('🎵 PlaybackState: ${playbackState.value}');
      debugPrint('🎵 Player Playing: ${_player.playing}');
      debugPrint('🎵 Current Index: $_currentIndex');
      debugPrint('🎵 Queue Length: ${_currentQueue.length}');
      
      if (_currentIndex < _currentQueue.length) {
        final song = _currentQueue[_currentIndex];
        debugPrint('🎵 Current Song: ${song.title}');
        debugPrint('🎵 Current Song Art URI: ${mediaItem.value?.artUri}');
      }
    } catch (e) {
      debugPrint('❌ MediaSession debug error: $e');
    }
  }

  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      debugPrint('🎵 Setting song: ${song.title}');

      if (song.uri.isEmpty) throw ArgumentError('Song URI cannot be empty');
      if (queue.isEmpty) throw ArgumentError('Queue cannot be empty');

      final initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) throw ArgumentError('Target song not found in queue');

      _currentQueue..clear()..addAll(queue);
      _currentIndex = initialIndex;

      await _safeStopPlayer();

      // Set MediaItem first
      final currentMediaItem = await _songToMediaItem(song);
      if (!mediaItem.isClosed) {
        mediaItem.value = currentMediaItem;
      }
      
      // Then set audio source
      final audioSources = queue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
      await _player.setAudioSources(audioSources, preload: true, initialIndex: initialIndex);

      await _player.setVolume(1.0);
      await _player.setSpeed(1.0);
      await _player.play();

      debugPrint('✅ Now playing: ${song.title}');
      
      // Force update for OxygenOS
      _updatePlaybackState(_player.playbackEvent);
      
      // Double update to ensure state propagation
      await Future.delayed(Duration(milliseconds: 500));
      _updatePlaybackState(_player.playbackEvent);
      
    } catch (e) {
      debugPrint('❌ Error setting song: $e');
      rethrow;
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

  // Basic controls
  @override
  Future<void> play() async {
    try {
      await _player.play();
      _updatePlaybackState(_player.playbackEvent);
    } catch (e) {
      debugPrint('❌ Error in play: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _updatePlaybackState(_player.playbackEvent);
    } catch (e) {
      debugPrint('❌ Error in pause: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _updatePlaybackState(_player.playbackEvent);
    } catch (e) {
      debugPrint('❌ Error in seek: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_currentIndex < _currentQueue.length - 1) {
        await _player.seekToNext();
        _updatePlaybackState(_player.playbackEvent);
      } else {
        await stop();
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
        _updatePlaybackState(_player.playbackEvent);
      } else {
        await _player.seek(Duration.zero);
        _updatePlaybackState(_player.playbackEvent);
      }
    } catch (e) {
      debugPrint('❌ Error in skipToPrevious: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _updatePlaybackState(_player.playbackEvent);
    } catch (e) {
      debugPrint('❌ Error in stop: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _player.dispose();
    debugPrint('🔥 BackgroundAudioHandler disposed');
  }

  Song? get currentSong {
    if (_currentIndex < _currentQueue.length) {
      return _currentQueue[_currentIndex];
    }
    return null;
  }
}