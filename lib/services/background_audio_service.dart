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

  // ✅ FIXED: Initialization completer
  final Completer<void> _initializationCompleter = Completer<void>();

  // Streams
  Stream<Duration> get durationStream => _player.durationStream.where((duration) => duration != null).cast<Duration>();
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  // Session persistence keys
  static const String _sessionKey = 'audio_session_data';
  static const String _queueKey = 'audio_queue_data';
  static const String _positionKey = 'audio_position';
  static const String _isPlayingKey = 'audio_is_playing';

  BackgroundAudioHandler() : _player = AudioPlayer() {
    _initializePlayer();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // ✅ FIXED: Initialization with proper completer handling
  Future<void> _initializePlayer() async {
    if (_isInitialized || _isDisposed) return;

    try {
      debugPrint('🔄 Starting audio handler initialization...');
      
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

      // ✅ DELAY session restore until songs are loaded
      await Future.delayed(const Duration(seconds: 2));
      await _restorePreviousSession();
      
      _setupAudioListeners();
      _isInitialized = true;
      
      // ✅ FIXED: COMPLETE THE COMPLETER
      _initializationCompleter.complete();
      
      debugPrint('✅ BackgroundAudioHandler fully initialized');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundAudioHandler: $e');
      // ✅ FIXED: Complete with error
      _initializationCompleter.completeError(e);
    }
  }

  // ✅ FIXED: Session restoration with better song matching
  Future<void> _restorePreviousSession() async {
    if (_isRestoringSession) return;
    
    _isRestoringSession = true;
    try {
      debugPrint('🔄 Attempting to restore previous audio session...');
      
      final prefs = await SharedPreferences.getInstance();
      
      if (!prefs.containsKey(_sessionKey)) {
        debugPrint('📭 No previous session found');
        _isRestoringSession = false;
        return;
      }

      final sessionData = prefs.getString(_sessionKey);
      if (sessionData == null || sessionData.isEmpty) {
        debugPrint('📭 Empty session data');
        _isRestoringSession = false;
        return;
      }

      // ✅ FIX: Pehle queue properly restore karo
      await _restoreQueueFromStorage();
      
      if (_currentQueue.isEmpty) {
        debugPrint('❌ No songs in restored queue');
        await _clearSessionData();
        _isRestoringSession = false;
        return;
      }

      final sessionMap = json.decode(sessionData) as Map<String, dynamic>;
      final currentSongId = sessionMap['currentSongId'] as String?;
      final currentSongTitle = sessionMap['currentSongTitle'] as String?;
      final currentSongArtist = sessionMap['currentSongArtist'] as String?;
      final currentPosition = prefs.getInt(_positionKey) ?? 0;
      final wasPlaying = prefs.getBool(_isPlayingKey) ?? false;

      debugPrint('🎵 Session Data - SongID: $currentSongId, Position: $currentPosition, WasPlaying: $wasPlaying, QueueLength: ${_currentQueue.length}');

      if (currentSongId != null) {
        // ✅ IMPROVED: Better song matching using multiple fields
        int songIndex = _currentQueue.indexWhere((song) => song.id == currentSongId);
        
        // ✅ FALLBACK: If ID not found, try matching by title and artist
        if (songIndex == -1 && currentSongTitle != null && currentSongArtist != null) {
          debugPrint('🔍 ID not found, trying title/artist match...');
          songIndex = _currentQueue.indexWhere((song) => 
            song.title == currentSongTitle && song.artist == currentSongArtist
          );
        }
        
        if (songIndex != -1) {
          _currentIndex = songIndex;
          final song = _currentQueue[songIndex];
          
          debugPrint('🎵 Restoring song: ${song.title} at index: $songIndex, position: $currentPosition ms');

          // Set MediaItem
          final mediaItemValue = await _songToMediaItem(song);
          if (!mediaItem.isClosed) {
            mediaItem.value = mediaItemValue;
          }

          // ✅ FIX: Player setup with proper waiting
          final audioSources = _currentQueue.map((s) => AudioSource.uri(Uri.parse(s.uri))).toList();
          
          debugPrint('🔧 Setting audio sources...');
          await _player.setAudioSources(audioSources, preload: true, initialIndex: songIndex);

          // ✅ FIX: Wait for player to be ready before seeking
          debugPrint('⏳ Waiting for player to be ready...');
          await _player.processingStateStream.firstWhere(
            (state) => state == ProcessingState.ready
          ).timeout(const Duration(seconds: 10));

          debugPrint('🎯 Seeking to position: $currentPosition');
          await _player.seek(Duration(milliseconds: currentPosition));

          // ✅ FIX: Restore play state
          if (wasPlaying) {
            debugPrint('▶️ Restoring playing state');
            await _player.play();
          } else {
            debugPrint('⏸️ Restoring paused state');
            await _player.pause();
          }

          _updatePlaybackState(_player.playbackEvent);
          debugPrint('✅ Session restored successfully!');
        } else {
          debugPrint('❌ Song not found in restored queue');
          await _clearSessionData();
        }
      }
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
      await _clearSessionData();
    } finally {
      _isRestoringSession = false;
    }
  }

  // ✅ FIXED: Wait for initialization to complete
  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initializationCompleter.future;
  }

  // ✅ FIXED: Save session with better data
  Future<void> _saveCurrentSession() async {
    try {
      // ✅ REMOVE RESTRICTIONS - Always try to save
      if (_currentQueue.isEmpty) return;
      
      final prefs = await SharedPreferences.getInstance();
      final currentSong = _currentQueue[_currentIndex];
      
      // ✅ IMPROVED: Save multiple identifiers for better matching
      final sessionData = {
        'currentSongId': currentSong.id,
        'currentSongTitle': currentSong.title, // ✅ Backup for matching
        'currentSongArtist': currentSong.artist, // ✅ Backup for matching
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_sessionKey, json.encode(sessionData));
      await prefs.setInt(_positionKey, _player.position.inMilliseconds);
      await prefs.setBool(_isPlayingKey, _player.playing);
      
      await _saveQueueToStorage();
      
      debugPrint('💾 Session SAVED - Song: ${currentSong.title}, Position: ${_player.position.inMilliseconds}ms');
    } catch (e) {
      debugPrint('❌ Error saving session: $e');
    }
  }

  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = _currentQueue.map((song) => song.toJson()).toList();
      await prefs.setString(_queueKey, json.encode(queueData));
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
    }
  }

  Future<void> _restoreQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = prefs.getString(_queueKey);
      
      if (queueData != null && queueData.isNotEmpty) {
        final List<dynamic> queueList = json.decode(queueData);
        _currentQueue.clear();
        _currentQueue.addAll(queueList.map((data) => Song.fromJson(data)));
        debugPrint('📂 Queue restored with ${_currentQueue.length} songs');
      }
    } catch (e) {
      debugPrint('❌ Error restoring queue: $e');
      _currentQueue.clear();
    }
  }

  Future<void> _clearSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_positionKey);
      await prefs.remove(_isPlayingKey);
      await prefs.remove(_queueKey);
    } catch (e) {
      debugPrint('❌ Error clearing session data: $e');
    }
  }

  void _setupAudioListeners() {
    _player.playbackEventStream.listen((event) {
      _updatePlaybackState(event);
      _saveCurrentSession();
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

    _player.positionStream.listen((position) {
      if (_player.playing && position.inSeconds % 5 == 0) {
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

  void testMediaSession() {
    try {
      debugPrint('🎯 Testing MediaSession...');
      if (_currentIndex < _currentQueue.length) {
        final song = _currentQueue[_currentIndex];
        debugPrint('🎵 Current Song: ${song.title}');
        _updateCurrentMediaItem();
        _updatePlaybackState(_player.playbackEvent);
        debugPrint('✅ MediaSession test completed');
      }
    } catch (e) {
      debugPrint('❌ MediaSession test error: $e');
    }
  }

  @override
  Future<dynamic> customAction(String name, [dynamic extras]) async {
    debugPrint('🎛️ Custom action: $name');

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
        await _clearSessionData();
        return 'session_cleared';

      case 'clearForRecentClose':
        await _clearSessionData();
        await _safeStopPlayer();
        _currentQueue.clear();
        _currentIndex = 0;
        if (!mediaItem.isClosed) {
          mediaItem.value = null;
        }
        return 'cleared_for_recent';

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

  // ✅ FIXED: setSong method with initialization wait
  Future<void> setSong(Song song, List<Song> queue) async {
    try {
      // ✅ FIX: Wait for initialization to complete
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
      
      // ✅ FIX: Wait for player to be ready
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.ready
      ).timeout(const Duration(seconds: 10));
      
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
      await _clearSessionData();
    } catch (e) {
      debugPrint('❌ Error in stop: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _saveCurrentSession();
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