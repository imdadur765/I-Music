// lib/services/background_audio_service.dart - SWIPE KILL FIXED VERSION
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song_model.dart';
import 'album_art_service.dart';

class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final List<Song> _currentQueue = [];
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isRestoringSession = false;

  final Completer<void> _initializationCompleter = Completer<void>();

  // ✅ SWIPE KILL PROTECTION - Track if app was killed
  static bool _wasAppKilled = false;
  static bool _isServiceRunning = false;

  // Streams
  Stream<Duration> get durationStream => _player.durationStream.where((duration) => duration != null).cast<Duration>();
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  // ✅ LIFETIME SESSION KEYS - NEVER EXPIRES
  static const String _sessionKey = 'audio_session_data_lifetime';
  static const String _queueKey = 'audio_queue_data_lifetime'; 
  static const String _positionKey = 'audio_position_lifetime';
  static const String _isPlayingKey = 'audio_is_playing_lifetime';
  static const String _wasKilledKey = 'audio_was_killed_flag';

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _isServiceRunning = true;
    _initializePlayer();
  }

  // ✅ SWIPE KILL DETECTION METHODS
  static Future<void> markAppKilled() async {
    _wasAppKilled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasKilledKey, true);
    debugPrint('🔴 SWIPE KILL: App killed flag set');
  }

  static Future<void> clearAppKilledFlag() async {
    _wasAppKilled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wasKilledKey);
    debugPrint('🟢 SWIPE KILL: App killed flag cleared');
  }

  static Future<bool> wasAppKilled() async {
    if (_wasAppKilled) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wasKilledKey) ?? false;
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // ✅ SWIPE KILL AWARE INITIALIZATION
  Future<void> _initializePlayer() async {
    if (_isInitialized || _isDisposed) return;

    try {
      debugPrint('🔄 SWIPE KILL INIT: Starting audio handler...');
      
      // ✅ Check if app was killed by swipe
      final killed = await wasAppKilled();
      if (killed) {
        debugPrint('🔄 SWIPE KILL DETECTED: Restoring from killed state...');
        await clearAppKilledFlag();
      }
      
      // ✅ Audio session setup with SWIPE KILL protection
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

      debugPrint('🎵 Audio session configured');

      // ✅ SWIPE KILL AWARE SESSION RESTORATION
      unawaited(SharedPreferences.getInstance().then(_restorePreviousSession));
      
      _setupAudioListeners();
      _isInitialized = true;
      _initializationCompleter.complete();
      
      debugPrint('✅ SWIPE KILL HANDLER: Fully initialized');
    } catch (e) {
      debugPrint('❌ SWIPE KILL INIT ERROR: $e');
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
      _isInitialized = true;
    }
  }

  // ✅ SWIPE KILL RESISTANT SESSION RESTORATION
  Future<void> _restorePreviousSession(SharedPreferences prefs) async {
    if (_isRestoringSession) return;
    
    _isRestoringSession = true;
    try {
      debugPrint('🔄 SWIPE KILL RESTORE: Attempting to restore session...');
      
      // ✅ Check if lifetime session exists
      if (!prefs.containsKey(_sessionKey)) {
        debugPrint('📭 No lifetime session found - FRESH START');
        _isRestoringSession = false;
        return;
      }

      final sessionData = prefs.getString(_sessionKey);
      if (sessionData == null || sessionData.isEmpty) {
        debugPrint('📭 Empty lifetime session data');
        _isRestoringSession = false;
        return;
      }

      // ✅ RESTORE QUEUE FROM PERMANENT STORAGE
      await _restoreQueueFromStorage(prefs);
      
      if (_currentQueue.isEmpty) {
        debugPrint('❌ No songs in lifetime queue');
        await _clearSessionData(prefs);
        _isRestoringSession = false;
        return;
      }

      final sessionMap = json.decode(sessionData) as Map<String, dynamic>;
      final currentSongId = sessionMap['currentSongId'] as String?;
      final currentSongTitle = sessionMap['currentSongTitle'] as String?;
      final currentSongArtist = sessionMap['currentSongArtist'] as String?;
      final currentPosition = prefs.getInt(_positionKey) ?? 0;

      debugPrint('🎵 SWIPE KILL SESSION - Song: $currentSongTitle, Position: $currentPosition ms');

      if (currentSongId != null) {
        // ✅ SMART SONG MATCHING FOR SWIPE KILL RECOVERY
        int songIndex = _currentQueue.indexWhere((song) => song.id == currentSongId);
        
        // Fallback matching by title and artist
        if (songIndex == -1 && currentSongTitle != null) {
          songIndex = _currentQueue.indexWhere((song) => 
            song.title == currentSongTitle && song.artist == currentSongArtist
          );
        }
        
        if (songIndex != -1) {
          _currentIndex = songIndex;
          final song = _currentQueue[songIndex];
          
          debugPrint('🎵 SWIPE KILL RESTORE SUCCESS: ${song.title} at ${currentPosition}ms');

          // ✅ SET MEDIAITEM
          final mediaItemValue = await _songToMediaItem(song);
          if (!mediaItem.isClosed) {
            mediaItem.value = mediaItemValue;
          }

          // ✅ SET AUDIO SOURCES
          final audioSources = _currentQueue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
          await _player.setAudioSources(audioSources, preload: true, initialIndex: songIndex);

          // ✅ WAIT FOR PLAYER READY
          await _player.processingStateStream.firstWhere(
            (state) => state == ProcessingState.ready
          ).timeout(const Duration(seconds: 5));

          // ✅ RESTORE EXACT POSITION
          await _player.seek(Duration(milliseconds: currentPosition));
          
          // ✅ ALWAYS PAUSE - NO AUTO PLAY AFTER SWIPE KILL
          await _player.pause();

          _updatePlaybackState(_player.playbackEvent);
          debugPrint('✅ SWIPE KILL SESSION RESTORED! Survived app termination.');
          
        } else {
          debugPrint('❌ Song not found in current library after swipe kill');
          await _clearSessionData(prefs);
        }
      }
    } catch (e) {
      debugPrint('❌ SWIPE KILL RESTORE ERROR: $e');
      await _clearSessionData(prefs);
    } finally {
      _isRestoringSession = false;
    }
  }

  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initializationCompleter.future;
  }

  // ✅ SWIPE KILL RESISTANT SESSION SAVE
  Future<void> _saveCurrentSession() async {
    try {
      if (_currentQueue.isEmpty || _currentIndex >= _currentQueue.length) return;
      
      final prefs = await SharedPreferences.getInstance();
      final currentSong = _currentQueue[_currentIndex];
      
      // ✅ PERMANENT SESSION DATA - SURVIVES SWIPE KILL
      final sessionData = {
        'currentSongId': currentSong.id,
        'currentSongTitle': currentSong.title,
        'currentSongArtist': currentSong.artist,
        'savedAt': DateTime.now().toIso8601String(),
      };

      // ✅ BATCH SAVE FOR PERFORMANCE
      await Future.wait([
        prefs.setString(_sessionKey, json.encode(sessionData)),
        prefs.setInt(_positionKey, _player.position.inMilliseconds),
        prefs.setBool(_isPlayingKey, _player.playing),
        _saveQueueToStorage(prefs),
      ]);
      
      debugPrint('💾 SWIPE KILL SAVE: ${currentSong.title} at ${_player.position.inMilliseconds}ms');
    } catch (e) {
      debugPrint('❌ SWIPE KILL SAVE ERROR: $e');
    }
  }

  Future<void> _saveQueueToStorage(SharedPreferences prefs) async {
    try {
      final queueData = _currentQueue.map((song) => song.toJson()).toList();
      await prefs.setString(_queueKey, json.encode(queueData));
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
    }
  }

  Future<void> _restoreQueueFromStorage(SharedPreferences prefs) async {
    try {
      final queueData = prefs.getString(_queueKey);
      
      if (queueData != null && queueData.isNotEmpty) {
        final List<dynamic> queueList = json.decode(queueData);
        _currentQueue.clear();
        _currentQueue.addAll(queueList.map((data) => Song.fromJson(data)));
        debugPrint('📂 Swipe kill queue restored with ${_currentQueue.length} songs');
      }
    } catch (e) {
      debugPrint('❌ Error restoring queue: $e');
      _currentQueue.clear();
    }
  }

  // ✅ SWIPE KILL AWARE SESSION CLEAR
  Future<void> _clearSessionData(SharedPreferences prefs) async {
    try {
      await prefs.remove(_sessionKey);
      await prefs.remove(_positionKey);
      await prefs.remove(_isPlayingKey);
      await prefs.remove(_queueKey);
      await prefs.remove(_wasKilledKey);
      debugPrint('🗑️ SWIPE KILL SESSION: Cleared permanently');
    } catch (e) {
      debugPrint('❌ Error clearing session data: $e');
    }
  }

  void _setupAudioListeners() {
    _player.playbackEventStream.listen((event) {
      _updatePlaybackState(event);
      _saveCurrentSession(); // ✅ Auto-save on state changes
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleTrackCompletion();
      }
      _saveCurrentSession();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < _currentQueue.length) {
        _currentIndex = index;
        _updateCurrentMediaItem();
        _saveCurrentSession();
      }
    });

    // ✅ OPTIMIZED: Save every 15 seconds while playing
    _player.positionStream.listen((position) {
      if (_player.playing && position.inSeconds % 15 == 0) {
        _saveCurrentSession();
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

  // ✅ SWIPE KILL TEST METHOD
  void testMediaSession() {
    try {
      debugPrint('🎯 Testing MediaSession with Swipe Kill protection...');
      if (_currentIndex < _currentQueue.length) {
        final song = _currentQueue[_currentIndex];
        debugPrint('🎵 Current Song: ${song.title}');
        _updateCurrentMediaItem();
        _updatePlaybackState(_player.playbackEvent);
        debugPrint('✅ MediaSession test completed - Swipe Kill Ready');
      }
    } catch (e) {
      debugPrint('❌ MediaSession test error: $e');
    }
  }

  @override
 Future<dynamic> customAction(String name, [dynamic extras]) async {
  debugPrint('🎛️ Custom action: $name');

  switch (name) {
    case 'setSongWithQueue':
      final songData = extras['song'] as Map<String, dynamic>;
      final queueData = extras['queue'] as List<dynamic>;
      
      final song = Song.fromJson(songData);
      final queue = queueData.map((data) => Song.fromJson(data)).toList();
      
      await setSong(song, queue);
      return 'song_and_queue_set';

      case 'setVolume':
      final volume = extras['volume'] as double;
      await setVolume(volume);
      return 'volume_set';

      case 'stopFromNative':
        await stop();
        return 'stopped';

      case 'forceSaveSession':
        await _saveCurrentSession();
        return 'session_saved';

      case 'getSessionInfo':
        return await getCurrentSessionInfo();

      case 'clearSession':
        await _clearSessionData(await SharedPreferences.getInstance());
        return 'session_cleared';

      case 'clearForCloseButton':
        await _clearSessionData(await SharedPreferences.getInstance());
        await _safeStopPlayer();
        _currentQueue.clear();
        _currentIndex = 0;
        if (!mediaItem.isClosed) {
          mediaItem.value = null;
        }
        _updatePlaybackState(_player.playbackEvent);
        return 'cleared_for_close_button';

      // ✅ SWIPE KILL SPECIFIC ACTIONS
      case 'markAppKilled':
        await markAppKilled();
        return 'swipe_kill_marked';

      case 'clearAppKilledFlag':
        await clearAppKilledFlag();
        return 'swipe_kill_cleared';

      case 'checkSwipeKillStatus':
        return {
          'wasKilled': await wasAppKilled(),
          'isServiceRunning': _isServiceRunning,
          'hasSession': (await SharedPreferences.getInstance()).containsKey(_sessionKey),
        };

      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> getCurrentSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hasSession': prefs.containsKey(_sessionKey),
      'currentSong': currentSong?.title,
      'position': _player.position,
      'isPlaying': _player.playing,
      'queueLength': _currentQueue.length,
      'wasAppKilled': await wasAppKilled(),
      'isServiceRunning': _isServiceRunning,
    };
  }

  // Album Art and MediaItem methods
  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      Uint8List? albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      Uri? artUri;

      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_album_art_${song.mediaStoreId}.jpg');
        await tempFile.writeAsBytes(albumArtBytes);
        artUri = tempFile.uri;
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
          'mediaStoreId': song.mediaStoreId.toString(),
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating MediaItem: $e');
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        extras: {'uri': song.uri},
      );
    }
  }

  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      await waitForInitialization();
      
      debugPrint('🎵 Setting song: ${song.title}');

      if (song.uri.isEmpty) throw ArgumentError('Song URI cannot be empty');
      if (queue.isEmpty) throw ArgumentError('Queue cannot be empty');

      final initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) throw ArgumentError('Target song not found in queue');

      _currentQueue..clear()..addAll(queue);
      _currentIndex = initialIndex;

      await _safeStopPlayer();

      // Set MediaItem
      final currentMediaItem = await _songToMediaItem(song);
      if (!mediaItem.isClosed) {
        mediaItem.value = currentMediaItem;
      }

      // Set audio source
      final audioSources = queue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
      await _player.setAudioSources(audioSources, preload: true, initialIndex: initialIndex);

      await _player.setVolume(1.0);
      
      // Wait for player to be ready
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.ready
      ).timeout(const Duration(seconds: 5));
      
      await _player.play();
      debugPrint('▶️ Starting playback for new song');

      await _saveCurrentSession();
      _updatePlaybackState(_player.playbackEvent);

    } catch (e) {
      debugPrint('❌ Error setting song: $e');
      rethrow;
    }
  }

  bool get isRestoringSession => _isRestoringSession;

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

  @override
  Future<void> play() async {
    try {
      await _player.play();
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
    } catch (e) {
      debugPrint('❌ Error in play: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
    } catch (e) {
      debugPrint('❌ Error in pause: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
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
        await _saveCurrentSession();
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
        await _saveCurrentSession();
      } else {
        await _player.seek(Duration.zero);
        _updatePlaybackState(_player.playbackEvent);
        await _saveCurrentSession();
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
      // ❌ DON'T clear session on stop - keep it for swipe kill recovery
    } catch (e) {
      debugPrint('❌ Error in stop: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _isServiceRunning = false;
    await _saveCurrentSession(); // ✅ Save before dispose for swipe kill
    await _player.dispose();
  }

  Song? get currentSong {
    if (_currentIndex < _currentQueue.length) {
      return _currentQueue[_currentIndex];
    }
    return null;
  }

  List<Song> get currentQueue => _currentQueue;
  int get currentIndex => _currentIndex;
}