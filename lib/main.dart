// lib/main.dart - COMPLETE ERROR-FREE SWIPE KILL LIFETIME SESSION VERSION WITH PRELOADING
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:i_music/services/local_songs_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'providers/app_providers.dart';
import 'services/lyrics_cache_service.dart';
import 'app.dart';
import 'models/song_model.dart';
import 'models/playlist_model.dart';
import 'services/background_audio_service.dart';
import 'services/album_art_service.dart';
import 'services/preload_service.dart'; // ✅ ADD PRELOAD SERVICE

// ✅ Global audio handler
late AudioHandler globalAudioHandler;
const MethodChannel _nativeChannel = MethodChannel('i_music/media_store');
bool _hasStoragePermission = false;

// ✅ SWIPE KILL: Close type detection
bool _isFromCloseButton = false;
Timer? _closeDetectionTimer;

// ✅ SWIPE KILL: App running state
bool _isAppRunning = false;

// ✅ PRELOADING: Track preloading state
bool _isPreloadingThumbnails = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (_isAppRunning) {
    debugPrint('📱 App already running');
    return;
  }

  try {
    debugPrint('🎵 STARTING i_music APP WITH SWIPE KILL PROTECTION & PRELOADING...');

    // ✅ STEP 1: Basic configuration (FAST)
    await requestInitialPermissions();

    // ✅ STEP 2: Initialize Hive (FAST) - YE PEHLE AAYEGA
    await _initializeHive();

    // ✅ STEP 3: Initialize Album Art Lifetime Cache
    await AlbumArtService.init();

    // ✅ STEP 4: Initialize Preload Service
    await PreloadService.init(); // ✅ ADD PRELOAD SERVICE INIT

    // ✅ STEP 5: OnlineCacheService.init() ko Hive ke BAAD call karo
    await LyricsCacheService.init();

    // ✅ STEP 6: Initialize Audio Service (NON-BLOCKING)
    globalAudioHandler = await _initializeAudioServiceNonBlocking();
    final localSongsService = LocalSongsService();
    final permissions = await localSongsService.checkPermissions();
  
    if (!permissions['hasStoragePermission']!) {
    await localSongsService.requestPermissions();
    }
    // ✅ STEP 7: Setup SWIPE KILL lifecycle listeners
    _setupAppLifecycleListeners();
    
    // ✅ STEP 8: Start app immediately
    _isAppRunning = true;
    runApp(const ProviderScope(child: IMusicAppWithPreloading())); // ✅ CHANGE TO PRELOADING VERSION
    
    // ✅ STEP 9: Start non-critical initializations in background
    unawaited(_initializeBackgroundComponents());

    debugPrint('🎵 i_music APP STARTED WITH SWIPE KILL PROTECTION & PRELOADING!');
    
  } catch (error, stack) {
    debugPrint('❌ App initialization failed: $error');
    debugPrint('Stack: $stack');
    _runFallbackAppWithAutoRetry();
  }
}

// ✅ PRELOADING: New app wrapper with preloading functionality
class IMusicAppWithPreloading extends ConsumerWidget {
  const IMusicAppWithPreloading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Preload thumbnails when app starts and songs are loaded
    final songsAsync = ref.watch(songsProvider);
    
    songsAsync.whenData((songs) {
      if (songs.isNotEmpty && !_isPreloadingThumbnails) {
        _isPreloadingThumbnails = true;
        // ✅ Start preloading in background without blocking UI
        unawaited(_startBackgroundPreloading(songs));
      }
    });

    return const IMusicApp(); // ✅ Return your original app
  }

  // ✅ Background preloading without blocking UI
  Future<void> _startBackgroundPreloading(List<Song> songs) async {
    try {
      debugPrint('🚀 Starting background thumbnail preloading for ${songs.length} songs...');
      
      // ✅ Use the preload service to load thumbnails in background
      await PreloadService().preloadAllThumbnails(songs);
      
      debugPrint('✅ Background thumbnail preloading completed');
    } catch (e) {
      debugPrint('⚠️ Background preloading error: $e');
    } finally {
      _isPreloadingThumbnails = false;
    }
  }
}

// ✅ SWIPE KILL: Non-blocking Audio Service initialization
Future<AudioHandler> _initializeAudioServiceNonBlocking() async {
  debugPrint('🔊 Starting Audio Service initialization with Swipe Kill protection...');

  try {
    // ✅ ATTEMPT 1: Quick AudioService.init with shorter timeout
    final audioHandler = await AudioService.init(
      builder: () => BackgroundAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.imusic.channel.audio',
        androidNotificationChannelName: 'i_music Player',
        androidNotificationChannelDescription: 'Audio playback controls',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        preloadArtwork: true,
        androidResumeOnClick: true,
        notificationColor: Colors.deepPurple,
        androidNotificationIcon: 'drawable/ic_notification',
      ),
    ).timeout(const Duration(seconds: 8));

    debugPrint('✅ Audio Service initialized via standard method');
    return audioHandler;
    
  } catch (e) {
    debugPrint('⚠️ Standard AudioService.init had issues: $e');
    
    // ✅ FALLBACK: Create handler directly but DON'T wait
    debugPrint('🔄 Creating BackgroundAudioHandler directly with Swipe Kill protection...');
    final directHandler = BackgroundAudioHandler();
    
    // ✅ CRITICAL: Don't wait for full initialization - let it happen in background
    debugPrint('✅ Direct BackgroundAudioHandler created (initializing in background)');
    return directHandler;
  }
}

// ✅ SWIPE KILL: Album Art Cache Initialization
Future<void> _initializeAlbumArtCache() async {
  try {
    // ✅ OPEN LIFETIME CACHE BOX FOR ALBUM ARTS
    await Hive.openBox<String>('albumArtLifetimeCache');
    debugPrint('💾 Album Art Lifetime Cache initialized');
  } catch (e) {
    debugPrint('❌ Error initializing album art cache: $e');
  }
}

// ✅ SWIPE KILL: Initialize background components without blocking
Future<void> _initializeBackgroundComponents() async {
  try {
    await AlbumArtService.init().timeout(const Duration(seconds: 5));
    await _checkAndRequestStoragePermission().timeout(const Duration(seconds: 5));
    _setupNativeMethodHandler();
    unawaited(_preloadAlbumArtsInBackground());
    debugPrint('✅ Background components initialized');
  } catch (e) {
    debugPrint('⚠️ Background components had issues: $e');
  }
}

// ✅ SWIPE KILL: Background album art preloading
Future<void> _preloadAlbumArtsInBackground() async {
  try {
    debugPrint('💾 Starting background album art preloading...');
    debugPrint('💾 Background album art preloading completed');
  } catch (e) {
    debugPrint('⚠️ Background album art preloading error: $e');
  }
}

// ✅ SWIPE KILL: Fallback with immediate auto-retry
void _runFallbackAppWithAutoRetry() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
              SizedBox(height: 20),
              Text('I Music', style: TextStyle(fontSize: 24, color: Colors.white)),
              SizedBox(height: 10),
              Text('Starting app...\nPlease wait',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    ),
  );
  
  // ✅ AUTO-RETRY after 1 second (user won't even notice)
  Future.delayed(const Duration(seconds: 1), () {
    _retryInitialization();
  });
}

// ✅ SWIPE KILL: Simple retry mechanism
void _retryInitialization() {
  debugPrint('🔄 Auto-retry initialization...');
  _isAppRunning = false;
  main();
}

// ✅ SWIPE KILL: App lifecycle with session persistence
void _setupAppLifecycleListeners() {
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      audioHandler: globalAudioHandler,
      // ✅ SWIPE KILL: Correct parameter names
      resumeCallBack: () async {
        debugPrint('📱 App resumed - checking swipe kill status...');
        
        // ✅ SWIPE KILL: Clear the app killed flag on resume
        await BackgroundAudioHandler.clearAppKilledFlag();
        
        _closeDetectionTimer?.cancel();
        _isFromCloseButton = false;
        debugPrint('🟢 SWIPE KILL: App resumed - session active');
      },
      detachedCallBack: () async {
        debugPrint('📱 App detached - checking close type for swipe kill...');
        try {
          _closeDetectionTimer?.cancel();
          
          if (_isFromCloseButton) {
            debugPrint('🚫 CLOSE BUTTON: Clearing lifetime session');
            await _clearForCloseButton(globalAudioHandler);
          } else {
            debugPrint('💾 SWIPE CLOSE: Saving lifetime session and marking swipe kill');
            await _saveAudioSession(globalAudioHandler);
            // ✅ SWIPE KILL: Mark app as killed for proper restoration
            await BackgroundAudioHandler.markAppKilled();
          }
        } catch (e) {
          debugPrint('⚠️ App detached handling error: $e');
        } finally {
          _isFromCloseButton = false;
        }
      },
      pauseCallBack: () async {
        debugPrint('📱 App paused - starting close detection for swipe kill');
        _startCloseButtonDetection();
      },
      // ✅ SWIPE KILL: Add hidden state handling
      hiddenCallBack: () async {
        debugPrint('📱 App hidden - quick save for swipe kill protection');
        await _quickSaveSession(globalAudioHandler);
      },
    ),
  );
}

// ✅ SWIPE KILL: Quick session save for hidden state
Future<void> _quickSaveSession(AudioHandler audioHandler) async {
  try {
    if (audioHandler is BackgroundAudioHandler) {
      await audioHandler.customAction('forceSaveSession');
      debugPrint('💾 SWIPE KILL: Quick session saved');
    }
  } catch (e) {
    debugPrint('⚠️ Quick session save error: $e');
  }
}

// ✅ SWIPE KILL: Close button detection
void _startCloseButtonDetection() {
  _closeDetectionTimer?.cancel();
  _closeDetectionTimer = Timer(const Duration(milliseconds: 150), () {
    _isFromCloseButton = true;
    debugPrint('🔍 SWIPE KILL: Close button detection active');
  });
}

// ✅ SWIPE KILL: Clear session for close button
Future<void> _clearForCloseButton(AudioHandler audioHandler) async {
  try {
    if (audioHandler is BackgroundAudioHandler) {
      await audioHandler.customAction('clearForCloseButton');
      // ✅ SWIPE KILL: Also clear the killed flag
      await BackgroundAudioHandler.clearAppKilledFlag();
      debugPrint('✅ SWIPE KILL: Session cleared for close button');
    }
  } catch (e) {
    debugPrint('❌ Error clearing for close button: $e');
  }
}

// ✅ SWIPE KILL: Save audio session
Future<void> _saveAudioSession(AudioHandler audioHandler) async {
  try {
    if (audioHandler is BackgroundAudioHandler) {
      await audioHandler.customAction('forceSaveSession');
      debugPrint('💾 SWIPE KILL: Session saved for lifetime');
    }
  } catch (e) {
    debugPrint('⚠️ Session save error: $e');
  }
}

// ✅ SWIPE KILL: Enhanced LifecycleEventHandler class
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? detachedCallBack;
  final AsyncCallback? pauseCallBack;
  final AsyncCallback? hiddenCallBack;
  final AudioHandler audioHandler;

  // ✅ SWIPE KILL: Correct constructor parameter names
  LifecycleEventHandler({
    this.resumeCallBack, 
    this.detachedCallBack,
    this.pauseCallBack,
    this.hiddenCallBack,
    required this.audioHandler,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 SWIPE KILL: App resumed');
        if (resumeCallBack != null) await resumeCallBack!();
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 SWIPE KILL: App detached');
        if (detachedCallBack != null) await detachedCallBack!();
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 SWIPE KILL: App inactive');
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 SWIPE KILL: App paused');
        if (pauseCallBack != null) await pauseCallBack!();
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 SWIPE KILL: App hidden - quick saving session');
        if (hiddenCallBack != null) await hiddenCallBack!();
        break;
    }
  }
}

// ✅ SWIPE KILL: Native method handler
void _setupNativeMethodHandler() {
  _nativeChannel.setMethodCallHandler((call) async {
    debugPrint('📱 Native method called: ${call.method}');

    try {
      switch (call.method) {
        case 'stopAudioService':
          debugPrint('🛑 Stopping audio service from native...');
          await _stopAudioServiceCompletely();
          return 'Audio service stopped';
        
        case 'onPermissionsResult':
          debugPrint('🔐 Permissions result received from native');
          await _checkAndRequestStoragePermission();
          return 'Permissions handled';

        case 'refreshMediaSession':
          debugPrint('🔄 Refreshing MediaSession from native');
          _refreshMediaSession();
          return 'MediaSession refreshed';

        // ✅ SWIPE KILL: Native methods for testing
        case 'checkSwipeKillStatus':
          debugPrint('🔍 Checking swipe kill status from native');
          final status = await BackgroundAudioHandler.wasAppKilled();
          return {'wasKilled': status};

        case 'markAppKilled':
          debugPrint('🔴 Marking app as killed from native');
          await BackgroundAudioHandler.markAppKilled();
          return 'App killed marked';

        default:
          debugPrint('❌ Unknown native method: ${call.method}');
          throw PlatformException(
            code: 'UNKNOWN_METHOD',
            message: 'Method ${call.method} not implemented',
          );
      }
    } catch (e) {
      debugPrint('❌ Error in native method handler: $e');
      rethrow;
    }
  });
}

// ✅ SWIPE KILL: MediaSession refresh function
void _refreshMediaSession() {
  try {
    debugPrint('🔄 Refreshing MediaSession state...');
    final audioHandler = globalAudioHandler;
    if (audioHandler is BackgroundAudioHandler) {
      audioHandler.playbackState.add(audioHandler.playbackState.value);
      debugPrint('✅ MediaSession refreshed');
    }
  } catch (e) {
    debugPrint('⚠️ MediaSession refresh error: $e');
  }
}

// ✅ SWIPE KILL: Safe audio handler access
AudioHandler getAudioHandler() {
  return globalAudioHandler;
}

// ✅ SWIPE KILL: Audio service running check
Future<bool> isAudioServiceRunning() async {
  try {
    // ignore: deprecated_member_use
    return AudioService.running;
  } catch (e) {
    return false;
  }
}

// ✅ SWIPE KILL: Complete audio service shutdown
Future<void> _stopAudioServiceCompletely() async {
  debugPrint('🔴 Starting complete audio service shutdown...');

  try {
    // Step 1: Stop audio playback using AudioHandler
    try {
      await globalAudioHandler.stop();
      debugPrint('✅ AudioHandler.stop() completed');
    } catch (e) {
      debugPrint('⚠️ AudioHandler.stop() error: $e');
    }

    // Step 2: Cleanup any stray players
    try {
      final tempPlayer = AudioPlayer();
      await tempPlayer.stop();
      await tempPlayer.dispose();
      debugPrint('✅ Audio players disposed');
    } catch (e) {
      debugPrint('⚠️ Audio player disposal error: $e');
    }

    debugPrint('✅ Complete audio service shutdown finished');
  } catch (e) {
    debugPrint('❌ Error during audio service shutdown: $e');
  }
}

// ✅ SWIPE KILL: Hive initialization
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());

    await _openBoxWithRecovery<Song>('favorites');
    await _openBoxWithRecovery<Playlist>('playlists');
    await _openBoxWithRecovery('recently_played');

    debugPrint('✅ Hive database initialized successfully');
  } catch (e) {
    debugPrint('❌ Hive initialization error: $e');
    rethrow;
  }
}

Future<void> _openBoxWithRecovery<T>(String boxName) async {
  try {
    await Hive.openBox<T>(boxName);
    debugPrint('✅ Hive box "$boxName" opened');
  } catch (e) {
    debugPrint('⚠️ Opening Hive box "$boxName" failed: $e — attempting recovery');
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (e2) {
      debugPrint('⚠️ Deleting Hive box "$boxName" failed: $e2');
    }
    await Hive.openBox<T>(boxName);
    debugPrint('✅ Hive box "$boxName" recovered');
  }
}

// ✅ SWIPE KILL: Android permission handling
Future<void> _requestAppPermissions() async {
  try {
    debugPrint('🔐 Requesting app permissions...');

    final isAndroid13OrAbove = await _isAndroid13OrAbove();
    debugPrint('📱 Android Version: ${isAndroid13OrAbove ? '13+' : '12 or below'}');

    List<Permission> permissionsToRequest = [
      Permission.notification,
    ];

    if (isAndroid13OrAbove) {
      permissionsToRequest.add(Permission.mediaLibrary);
      debugPrint('🎯 Using READ_MEDIA_AUDIO for Android 13+');
    } else {
      permissionsToRequest.add(Permission.storage);
      debugPrint('🎯 Using STORAGE for Android 12 or below');
    }

    // Check current status
    final permissionStatuses = await Future.wait(
      permissionsToRequest.map((permission) => permission.status)
    );

    // If already granted, return
    final allGranted = permissionStatuses.every((status) => status.isGranted);
    if (allGranted) {
      _hasStoragePermission = true;
      debugPrint('✅ All required permissions already granted');
      return;
    }

    // Request permissions
    final permissions = await permissionsToRequest.request();

    final hasMediaLibrary = permissions[Permission.mediaLibrary]?.isGranted ?? false;
    final hasStorage = permissions[Permission.storage]?.isGranted ?? false;

    _hasStoragePermission = isAndroid13OrAbove ? hasMediaLibrary : hasStorage;

    if (_hasStoragePermission) {
      debugPrint('✅ All critical permissions granted - Album art will work!');
    } else {
      debugPrint('❌ Storage permission not granted');
    }
  } catch (e) {
    debugPrint('❌ Permission error: $e');
    _hasStoragePermission = false;
  }
}

// ✅ SWIPE KILL: Storage permission check for album art
Future<void> _checkAndRequestStoragePermission() async {
  try {
    debugPrint('🎵 Checking storage permission for album art...');

    final isAndroid13OrAbove = await _isAndroid13OrAbove();
    final storagePermission = isAndroid13OrAbove ? Permission.mediaLibrary : Permission.storage;

    final status = await storagePermission.status;

    if (status.isGranted) {
      _hasStoragePermission = true;
      debugPrint('✅ Storage permission already granted for album art');
      return;
    }

    if (status.isDenied || status.isLimited) {
      final result = await storagePermission.request();
      _hasStoragePermission = result.isGranted;

      if (_hasStoragePermission) {
        debugPrint('✅ Storage permission granted - Album art will work!');
      } else {
        debugPrint('❌ Storage permission denied - Album art will not work');
      }
    } else if (status.isPermanentlyDenied) {
      debugPrint('🚫 Storage permission permanently denied - User needs to enable manually');
      _hasStoragePermission = false;
    }
  } catch (e) {
    debugPrint('❌ Storage permission check error: $e');
    _hasStoragePermission = false;
  }
}

// ✅ SWIPE KILL: Android version check
Future<bool> _isAndroid13OrAbove() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      debugPrint('📊 Detected Android SDK: $sdkVersion');
      return sdkVersion >= 33;
    }
    return false;
  } catch (e) {
    debugPrint('❌ Error checking Android version: $e');
    return true;
  }
}

// ✅ SWIPE KILL: Initial permissions
Future<void> requestInitialPermissions() async {
  if (!Platform.isAndroid) return;

  if (kDebugMode) {
    print('🔄 Requesting necessary permissions...');
  }

  // Audio Permission
  final audioStatus = await Permission.audio.request();
  if (audioStatus.isGranted) {
    if (kDebugMode) {
      print('✅ Audio permission granted');
    }
  } else {
    if (kDebugMode) {
      print('❌ Audio permission denied');
    }
  } 

  // Notification Permission
  final notificationStatus = await Permission.notification.request();
  if (notificationStatus.isGranted) {
    if (kDebugMode) {
      print('✅ Notification permission granted');
    }
  } else {
    if (kDebugMode) {
      print('❌ Notification permission denied');
    }
  }

  // Request app-specific permissions
  await _requestAppPermissions();

  if (audioStatus.isGranted && notificationStatus.isGranted) {
    if (kDebugMode) {
      print('🎉 All essential permissions granted!');
    }
  } else {
    if (kDebugMode) {
      print('⚠️ Some permissions were denied');
    }
  }
}

// ✅ SWIPE KILL: Test MediaSession function
Future<void> testMediaSession() async {
  try {
    debugPrint('🧪 Testing MediaSession functionality with Swipe Kill...');
    
    final audioHandler = getAudioHandler();
    
    final mediaItem = audioHandler.mediaItem.value;
    final playbackState = audioHandler.playbackState.value;
    
    debugPrint('🎵 Current MediaItem: ${mediaItem?.title}');
    debugPrint('🎵 MediaItem ID: ${mediaItem?.id}');
    debugPrint('🎵 Playback State: ${playbackState.playing}');
    debugPrint('🎵 Processing State: ${playbackState.processingState}');
    
    // ✅ SWIPE KILL: Test swipe kill status
    final wasKilled = await BackgroundAudioHandler.wasAppKilled();
    debugPrint('🔍 SWIPE KILL Status: $wasKilled');
    
    debugPrint('✅ MediaSession test completed with Swipe Kill check');
  } catch (e) {
    debugPrint('❌ MediaSession test failed: $e');
  }
}

// ✅ Manual permission request
Future<void> requestStoragePermission() async {
  if (await Permission.storage.request().isGranted) {
    if (kDebugMode) {
      print('✅ Storage permission granted');
    }
  } else {
    if (kDebugMode) {
      print('❌ Storage permission denied');
    }
  }
}

// ✅ Manual permission request
Future<void> requestPermissionsManually() async {
  try {
    debugPrint('👤 Manual permission request triggered');
    await _checkAndRequestStoragePermission();
  } catch (e) {
    debugPrint('❌ Manual permission request error: $e');
  }
}

// ✅ Getter for storage permission
bool get hasStoragePermission => _hasStoragePermission;

// ✅ SWIPE KILL: Retry mechanism in fallback app
void _runFallbackApp() {
  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.white),
              const SizedBox(height: 20),
              const Text('I Music', style: TextStyle(fontSize: 24, color: Colors.white)),
              const SizedBox(height: 10),
              const Text('Failed to initialize\nPlease restart/Clear App Data',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ✅ SWIPE KILL: Add this method to check current swipe kill status
Future<Map<String, dynamic>> getCurrentAppStatus() async {
  try {
    final wasKilled = await BackgroundAudioHandler.wasAppKilled();
    final audioHandler = globalAudioHandler;
    final hasSession = audioHandler.mediaItem.value != null;
    
    return {
      'wasAppKilled': wasKilled,
      'hasAudioSession': hasSession,
      'currentSong': audioHandler.mediaItem.value?.title,
      'isAppRunning': _isAppRunning,
      'hasStoragePermission': _hasStoragePermission,
      'isPreloadingThumbnails': _isPreloadingThumbnails, // ✅ ADD PRELOADING STATUS
    };
  } catch (e) {
    debugPrint('❌ Error getting app status: $e');
    return {'error': e.toString()};
  }
}