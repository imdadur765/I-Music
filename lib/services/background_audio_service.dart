// lib/services/background_audio_service.dart - SWIPE KILL FIXED + PERFORMANCE OPTIMIZED
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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

  // ✅ PERFORMANCE: Single completer for initialization
  final Completer<void> _initializationCompleter = Completer<void>();

  // ✅ SWIPE KILL PROTECTION - Optimized with static final
  static final _swipeKillFlags = <String, bool>{
    'wasAppKilled': false,
    'isServiceRunning': false,
  };

  // ✅ PERFORMANCE: Cache for MediaItems to avoid repeated conversions
  final Map<String, MediaItem> _mediaItemCache = {};
  final Map<String, Future<MediaItem>> _pendingMediaItemRequests = {};

  // ✅ PERFORMANCE: Stream controllers for efficient state management
  final _sessionUpdateController = StreamController<void>.broadcast();
  
  // ✅ LIFETIME SESSION KEYS - OPTIMIZED
  static const String _sessionKey = 'audio_session_permanent';
  static const String _queueKey = 'audio_queue_permanent'; 
  static const String _positionKey = 'audio_position_permanent';
  static const String _isPlayingKey = 'audio_is_playing_permanent';
  static const String _wasKilledKey = 'audio_was_killed_permanent';

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _swipeKillFlags['isServiceRunning'] = true;
    _initializePlayer();
  }

  // ✅ OPTIMIZED SWIPE KILL DETECTION
  static Future<void> markAppKilled() async {
    _swipeKillFlags['wasAppKilled'] = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasKilledKey, true);
  }

  static Future<void> clearAppKilledFlag() async {
    _swipeKillFlags['wasAppKilled'] = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wasKilledKey);
  }

  static Future<bool> wasAppKilled() async {
    if (_swipeKillFlags['wasAppKilled']!) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wasKilledKey) ?? false;
  }

  // ✅ PERFORMANCE OPTIMIZED: Batch volume operations
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // ✅ OPTIMIZED INITIALIZATION
  Future<void> _initializePlayer() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // ✅ Check swipe kill status first
      final killed = await wasAppKilled();
      if (killed) {
        await clearAppKilledFlag();
      }
      
      // ✅ Configure audio session
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

      // ✅ Start session restoration and listeners in parallel
      await Future.wait([
        SharedPreferences.getInstance().then(_restorePreviousSession),
        _setupAudioListeners(),
      ]);
      
      _isInitialized = true;
      _initializationCompleter.complete();
      
    } catch (e) {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
      _isInitialized = true;
    }
  }

  // ✅ OPTIMIZED SESSION RESTORATION
  Future<void> _restorePreviousSession(SharedPreferences prefs) async {
    if (_isRestoringSession) return;
    
    _isRestoringSession = true;
    try {
      // ✅ Quick check for session existence
      if (!prefs.containsKey(_sessionKey)) {
        _isRestoringSession = false;
        return;
      }

      final sessionData = prefs.getString(_sessionKey);
      if (sessionData == null || sessionData.isEmpty) {
        await _clearSessionData(prefs);
        _isRestoringSession = false;
        return;
      }

      // ✅ Restore queue first
      await _restoreQueueFromStorage(prefs);
      
      if (_currentQueue.isEmpty) {
        await _clearSessionData(prefs);
        _isRestoringSession = false;
        return;
      }

      final sessionMap = json.decode(sessionData) as Map<String, dynamic>;
      final currentSongId = sessionMap['currentSongId'] as String?;
      final currentPosition = prefs.getInt(_positionKey) ?? 0;

      if (currentSongId != null) {
        // ✅ Efficient song finding
        int songIndex = _currentQueue.indexWhere((song) => song.id == currentSongId);
        
        if (songIndex != -1) {
          _currentIndex = songIndex;
          final song = _currentQueue[songIndex];

          // ✅ Set media item using cached method
          final mediaItemValue = await _getCachedMediaItem(song);
          if (!mediaItem.isClosed) {
            mediaItem.value = mediaItemValue;
          }

          // ✅ Set audio sources
          final audioSources = _currentQueue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
          await _player.setAudioSources(audioSources, preload: true, initialIndex: songIndex);

          // ✅ Wait for player with timeout
          await _player.processingStateStream.firstWhere(
            (state) => state == ProcessingState.ready
          ).timeout(const Duration(seconds: 3));

          // ✅ Restore position and pause
          await _player.seek(Duration(milliseconds: currentPosition));
          await _player.pause();

          _updatePlaybackState(_player.playbackEvent);
        } else {
          await _clearSessionData(prefs);
        }
      }
    } catch (e) {
      await _clearSessionData(prefs);
    } finally {
      _isRestoringSession = false;
    }
  }

  // ✅ PERFORMANCE: Wait for initialization
  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initializationCompleter.future;
  }

  // ✅ OPTIMIZED SESSION SAVING
  Future<void> _saveCurrentSession() async {
    try {
      if (_currentQueue.isEmpty || _currentIndex >= _currentQueue.length) return;
      
      final prefs = await SharedPreferences.getInstance();
      final currentSong = _currentQueue[_currentIndex];
      
      // ✅ Efficient session data
      final sessionData = {
        'currentSongId': currentSong.id,
        'currentSongTitle': currentSong.title,
        'currentSongArtist': currentSong.artist,
      };

      // ✅ Batch save operations
      await Future.wait([
        prefs.setString(_sessionKey, json.encode(sessionData)),
        prefs.setInt(_positionKey, _player.position.inMilliseconds),
        prefs.setBool(_isPlayingKey, _player.playing),
        _saveQueueToStorage(prefs),
      ]);
    } catch (e) {
      // Silent fail - session saving shouldn't break the app
    }
  }

  // ✅ OPTIMIZED QUEUE STORAGE
  Future<void> _saveQueueToStorage(SharedPreferences prefs) async {
    try {
      // ✅ Only save essential song data
      final queueData = _currentQueue.map((song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'uri': song.uri,
        'duration': song.duration,
        'mediaStoreId': song.mediaStoreId,
      }).toList();
      
      await prefs.setString(_queueKey, json.encode(queueData));
    } catch (e) {
      // Silent fail
    }
  }

  // ✅ OPTIMIZED QUEUE RESTORATION
  Future<void> _restoreQueueFromStorage(SharedPreferences prefs) async {
    try {
      final queueData = prefs.getString(_queueKey);
      
      if (queueData != null && queueData.isNotEmpty) {
        final List<dynamic> queueList = json.decode(queueData);
        _currentQueue.clear();
        
        // ✅ Efficient song reconstruction
        _currentQueue.addAll(queueList.map((data) => Song(
          id: data['id'] as String,
          title: data['title'] as String,
          artist: data['artist'] as String,
          uri: data['uri'] as String,
          duration: data['duration'] as int,
          mediaStoreId: data['mediaStoreId'] as int,
          album: data['album'] as String?,
          albumArt: data['albumArt'] as String?,
          genre: data['genre'] as String?,
          trackNumber: (data['trackNumber'] as int?) ?? 0,
          year: (data['year'] as int?) ?? 0,
          composer: data['composer'] as String?,
          playCount: (data['playCount'] as int?) ?? 0,
          lastPlayed: data['lastPlayed'] != null 
              ? DateTime.parse(data['lastPlayed'] as String) 
              : DateTime.now(),
          dateAdded: data['dateAdded'] != null 
              ? DateTime.parse(data['dateAdded'] as String) 
              : DateTime.now(),
          isFavorite: (data['isFavorite'] as bool?) ?? false,
        )));
      }
    } catch (e) {
      _currentQueue.clear();
    }
  }

  // ✅ OPTIMIZED SESSION CLEARING
  Future<void> _clearSessionData(SharedPreferences prefs) async {
    try {
      await Future.wait([
        prefs.remove(_sessionKey),
        prefs.remove(_positionKey),
        prefs.remove(_isPlayingKey),
        prefs.remove(_queueKey),
        prefs.remove(_wasKilledKey),
      ]);
    } catch (e) {
      // Silent fail
    }
  }

  // ✅ PERFORMANCE OPTIMIZED AUDIO LISTENERS
  Future<void> _setupAudioListeners() async {
    // ✅ Debounced session saving
    Timer? _saveTimer;
    
    _player.playbackEventStream.listen((event) {
      _updatePlaybackState(event);
      
      // ✅ Debounce session saves to avoid excessive I/O
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), _saveCurrentSession);
    });

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

    // ✅ Optimized position streaming - less frequent updates
    _player.positionStream.listen((position) {
      if (_player.playing && position.inSeconds % 10 == 0) {
        _saveCurrentSession();
      }
    });
  }

  // ✅ OPTIMIZED PLAYBACK STATE UPDATES
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
      // Silent fail - playback state updates shouldn't break the app
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
      _getCachedMediaItem(_currentQueue[_currentIndex]).then((mediaItemValue) {
        mediaItem.value = mediaItemValue;
      });
    }
  }

  // ✅ PERFORMANCE: CACHED MEDIA ITEM CREATION
  Future<MediaItem> _getCachedMediaItem(Song song) async {
    // ✅ Return cached media item if available
    if (_mediaItemCache.containsKey(song.id)) {
      return _mediaItemCache[song.id]!;
    }

    // ✅ If request already pending, return that future
    if (_pendingMediaItemRequests.containsKey(song.id)) {
      return _pendingMediaItemRequests[song.id]!;
    }

    // ✅ Create new media item and cache it
    final completer = Completer<MediaItem>();
    _pendingMediaItemRequests[song.id] = completer.future;

    try {
      final mediaItem = await _songToMediaItem(song);
      _mediaItemCache[song.id] = mediaItem;
      completer.complete(mediaItem);
      _pendingMediaItemRequests.remove(song.id);
      return mediaItem;
    } catch (e) {
      completer.completeError(e);
      _pendingMediaItemRequests.remove(song.id);
      rethrow;
    }
  }

  // ✅ OPTIMIZED CUSTOM ACTIONS
  @override
  Future<dynamic> customAction(String name, [dynamic extras]) async {
    switch (name) {
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
        _mediaItemCache.clear(); // ✅ Clear cache
        if (!mediaItem.isClosed) {
          mediaItem.value = null;
        }
        _updatePlaybackState(_player.playbackEvent);
        return 'cleared_for_close_button';

      // ✅ SWIPE KILL ACTIONS
      case 'markAppKilled':
        await markAppKilled();
        return 'swipe_kill_marked';

      case 'clearAppKilledFlag':
        await clearAppKilledFlag();
        return 'swipe_kill_cleared';

      case 'checkSwipeKillStatus':
        return {
          'wasKilled': await wasAppKilled(),
          'isServiceRunning': _swipeKillFlags['isServiceRunning'],
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
      'isServiceRunning': _swipeKillFlags['isServiceRunning'],
    };
  }

  // ✅ PERFORMANCE OPTIMIZED MEDIA ITEM CREATION
  Future<MediaItem> _songToMediaItem(Song song) async {
    try {
      // ✅ Use cached album art if available
      Uint8List? albumArtBytes = await AlbumArtService.getAlbumArt(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );

      Uri? artUri;

      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/album_art_${song.mediaStoreId}.jpg');
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
          'song_object': song, // ✅ Store song object for quick access
        },
      );
    } catch (e) {
      // ✅ Fallback without album art
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

  // ✅ OPTIMIZED SONG SETTING
  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      await waitForInitialization();
      
      if (song.uri.isEmpty) throw ArgumentError('Song URI cannot be empty');
      if (queue.isEmpty) throw ArgumentError('Queue cannot be empty');

      final initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) throw ArgumentError('Target song not found in queue');

      _currentQueue
        ..clear()
        ..addAll(queue);
      _currentIndex = initialIndex;

      await _safeStopPlayer();

      // ✅ Use cached media item
      final currentMediaItem = await _getCachedMediaItem(song);
      if (!mediaItem.isClosed) {
        mediaItem.value = currentMediaItem;
      }

      // ✅ Set audio sources efficiently
      final audioSources = queue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
      await _player.setAudioSources(audioSources, preload: true, initialIndex: initialIndex);

      await _player.setVolume(1.0);
      
      // ✅ Wait for player with timeout
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.ready
      ).timeout(const Duration(seconds: 3));
      
      await _player.play();
      await _saveCurrentSession();
      _updatePlaybackState(_player.playbackEvent);

    } catch (e) {
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
      // Silent fail
    }
  }

  // ✅ OPTIMIZED AUDIO CONTROL METHODS
  @override
  Future<void> play() async {
    try {
      await _player.play();
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _updatePlaybackState(_player.playbackEvent);
      await _saveCurrentSession();
    } catch (e) {
      // Silent fail
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
      // Silent fail
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
      // Silent fail
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _updatePlaybackState(_player.playbackEvent);
    } catch (e) {
      // Silent fail
    }
  }

  // ✅ OPTIMIZED DISPOSE
  Future<void> dispose() async {
    _isDisposed = true;
    _swipeKillFlags['isServiceRunning'] = false;
    await _saveCurrentSession();
    await _player.dispose();
    await _sessionUpdateController.close();
  }

  // ✅ EFFICIENT GETTERS
  Song? get currentSong {
    if (_currentIndex < _currentQueue.length) {
      return _currentQueue[_currentIndex];
    }
    return null;
  }

  List<Song> get currentQueue => _currentQueue;
  int get currentIndex => _currentIndex;
  
  // ✅ PERFORMANCE: Stream getters
  Stream<Duration> get durationStream => _player.durationStream.where((duration) => duration != null).cast<Duration>();
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
}