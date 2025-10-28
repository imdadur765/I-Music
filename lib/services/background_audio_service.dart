// lib/services/background_audio_service.dart - COMPLETE FIXED VERSION
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';

class BackgroundAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final List<Song> _currentQueue = [];
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;

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

  // ✅ ADDED: Missing method
  void _handleTrackCompletion() {
    if (_currentIndex < _currentQueue.length - 1) {
      skipToNext();
    } else {
      _player.stop();
      _updatePlaybackState(_player.playbackEvent);
    }
  }

  // ✅ ADDED: Missing method
  void _updateCurrentMediaItem() {
    if (_currentIndex < _currentQueue.length && !mediaItem.isClosed) {
      mediaItem.add(_songToMediaItem(_currentQueue[_currentIndex]));
    }
  }

  // ✅ CRITICAL FIX: Override stop method for swipe close
  @override
  Future<void> stop() async {
    debugPrint('🛑 STOP CALLED - Preparing for app termination');
    await _forceCleanup();
    return super.stop();
  }

  // ✅ ADD THIS: Handle task removal (app killed by system)
  @override
  Future<void> onTaskRemoved() async {
    debugPrint('🔴 onTaskRemoved CALLED - App being killed by system');
    await _forceCleanup();
    await super.onTaskRemoved();
  }

  // ✅ ADD THIS: Handle custom actions (like from native)
  @override
  Future<dynamic> customAction(String name, [dynamic arguments]) async {
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

  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      if (song.uri.isEmpty) throw ArgumentError('Song URI cannot be empty');
      if (queue.isEmpty) throw ArgumentError('Queue cannot be empty');

      final initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) throw ArgumentError('Target song not found in queue');

      _currentQueue..clear()..addAll(queue);
      _currentIndex = initialIndex;

      await _safeStopPlayer();

      final mediaItems = queue.map(_songToMediaItem).toList();
      if (!mediaItem.isClosed) mediaItem.add(mediaItems[initialIndex]);
      if (!super.queue.isClosed) super.queue.add(mediaItems);

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
      if (!mediaItem.isClosed) mediaItem.add(_songToMediaItem(song));
      await _player.play();
      debugPrint('✅ Fallback playback successful');
    } catch (fallbackError) {
      debugPrint('❌ Fallback playback failed: $fallbackError');
    }
  }

  MediaItem _songToMediaItem(Song song) {
    Uri? artUri;
    try {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        if (song.albumArt!.startsWith('http')) artUri = Uri.parse(song.albumArt!);
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing album art: $e');
    }

    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album ?? 'Unknown Album',
      duration: Duration(milliseconds: song.duration),
      artUri: artUri,
      extras: {
        'uri': song.uri,
        'song_object': song,
        'album': song.album,
        'artist': song.artist,
      },
    );
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

  List<Song> get currentQueue => List.unmodifiable(_currentQueue);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex < _currentQueue.length ? _currentQueue[_currentIndex] : null;
  Duration? get duration => _player.duration;
  Duration get position => _player.position;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  Future<void> nuclearEmergencyStop() async {
    debugPrint('☢️ NUCLEAR EMERGENCY STOP CALLED');
    try {
      await _player.stop();
      await _player.dispose();
      _isDisposed = true;
      _currentQueue.clear();
      _currentIndex = 0;
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
      if (!mediaItem.isClosed) mediaItem.add(null);
      if (!queue.isClosed) queue.add([]);
      debugPrint('✅ NUCLEAR EMERGENCY STOP COMPLETED');
    } catch (e) {
      debugPrint('❌ Nuclear emergency stop failed: $e');
    }
  }

  Future<void> emergencyStop() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      _currentQueue.clear();
      _currentIndex = 0;
      debugPrint('✅ Emergency stop completed');
    } catch (e) {
      debugPrint('❌ Emergency stop failed: $e');
    }
  }

  Future<void> resetPlayer() async {
    try {
      await _safeStopPlayer();
      _currentQueue.clear();
      _currentIndex = 0;
      if (!mediaItem.isClosed) mediaItem.add(null);
      debugPrint('✅ Player reset successfully');
    } catch (e) {
      debugPrint('❌ Error resetting player: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('🔥 DISPOSE CALLED - Final cleanup');
    await _forceCleanup();
  }
}