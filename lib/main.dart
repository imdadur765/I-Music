// lib/main.dart - COMPLETE FIXED VERSION
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

import 'app.dart';
import 'models/song_model.dart';
import 'models/playlist_model.dart';
import 'services/background_audio_service.dart';

// ✅ FIXED: Use AudioHandler instead of BackgroundAudioHandler
late AudioHandler globalAudioHandler;
// ✅ ADD THIS: MethodChannel for native communication
final MethodChannel _nativeChannel = MethodChannel('i_music/media_store');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation early
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    debugPrint('🚀 Starting i_music app initialization...');

    // ✅ ADD THIS: Set up native method handler FIRST
    _setupNativeMethodHandler();

    // Attempt to fully stop any previously running audio service
    await _effectiveServiceCleanup();

    // Initialize Hive
    await _initializeHive();

    // Request critical permissions
    await _requestAppPermissions();

    // Initialize audio service (fresh)
    globalAudioHandler = await _initializeAudioService();

    debugPrint('🎵 i_music app started successfully!');
    runApp(const ProviderScope(child: IMusicApp()));
  } catch (error, stack) {
    debugPrint('❌ App initialization failed: $error');
    debugPrint('Stack: $stack');
    _runFallbackApp();
  }
}

// ✅ ADD THIS METHOD: Handle native method calls
void _setupNativeMethodHandler() {
  _nativeChannel.setMethodCallHandler((call) async {
    debugPrint('📱 Native method called: ${call.method}');
    
    switch (call.method) {
      case 'stopAudioService':
        debugPrint('🛑 Stopping audio service from native...');
        await _stopAudioServiceCompletely();
        return 'Audio service stopped';
      
      case 'onPermissionsResult':
        debugPrint('🔐 Permissions result received from native');
        return 'Permissions handled';
      
      default:
        debugPrint('❌ Unknown native method: ${call.method}');
        throw PlatformException(
          code: 'UNKNOWN_METHOD',
          message: 'Method ${call.method} not implemented',
        );
    }
  });
  debugPrint('✅ Native method handler setup completed');
}

// ✅ ADD THIS METHOD: Completely stop audio service
Future<void> _stopAudioServiceCompletely() async {
  debugPrint('🔴 Starting complete audio service shutdown...');
  
  try {
    // Step 1: Call native stop command on audio handler
    try {
      await globalAudioHandler.customAction('stopFromNative');
      debugPrint('✅ Native stop command sent to audio handler');
    } catch (e) {
      debugPrint('⚠️ Native stop command error: $e');
    }

    // Step 2: Stop audio playback
    try {
      await globalAudioHandler.stop();
      debugPrint('✅ AudioHandler.stop() completed');
    } catch (e) {
      debugPrint('⚠️ AudioHandler.stop() error: $e');
    }

    // Step 3: Stop AudioService
    try {
      await AudioService.stop();
      debugPrint('✅ AudioService.stop() completed');
    } catch (e) {
      debugPrint('⚠️ AudioService.stop() error: $e');
    }

    // Step 4: Stop and dispose any JustAudio players
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

/// EFFECTIVE SERVICE CLEANUP
Future<void> _effectiveServiceCleanup() async {
  debugPrint('🔄 Starting effective service cleanup...');

  // Strategy 1: Simply try to stop AudioService
  try {
    debugPrint('🛑 Attempting to stop AudioService...');
    await AudioService.stop();
    debugPrint('✅ AudioService.stop() completed');
  } catch (e) {
    debugPrint('✅ AudioService already stopped or not running: $e');
  }

  // Strategy 2: Cleanup any JustAudio players
  try {
    debugPrint('🔧 Cleaning up audio players...');
    final tempPlayer = AudioPlayer();
    await tempPlayer.stop();
    await tempPlayer.dispose();
    debugPrint('✅ Audio players cleaned up');
  } catch (e) {
    debugPrint('⚠️ Audio player cleanup warning: $e');
  }

  // Small delay to let system settle
  await Future.delayed(const Duration(milliseconds: 800));
  debugPrint('✅ Service cleanup completed');
}

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
    try {
      await Hive.close();
    } catch (_) {}
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

Future<void> _requestAppPermissions() async {
  try {
    final permissions = await [
      Permission.storage,
      Permission.audio,
      Permission.notification,
    ].request();

    final hasStorage = permissions[Permission.storage]?.isGranted ?? false;
    final hasAudio = permissions[Permission.audio]?.isGranted ?? false;

    if (!hasStorage || !hasAudio) {
      debugPrint('⚠️ Critical permissions not granted');
    } else {
      debugPrint('✅ All critical permissions granted');
    }
  } catch (e) {
    debugPrint('❌ Permission error: $e');
  }
}

Future<AudioHandler> _initializeAudioService() async {
  debugPrint('🔊 Starting FRESH Audio Service initialization...');

  try {
    final audioHandler = await AudioService.init(
      builder: () => BackgroundAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.imusic.channel.audio',
        androidNotificationChannelName: 'i_music Player',
        androidNotificationChannelDescription: 'Audio playback controls',
        androidStopForegroundOnPause: true, // ✅ CRITICAL: TRUE for swipe close
        androidShowNotificationBadge: true,
        preloadArtwork: true,
        androidResumeOnClick: true,
        notificationColor: Colors.deepPurple,
      ),
    );

    debugPrint('✅ Audio Service initialized successfully!');
    return audioHandler;
  } catch (e, st) {
    debugPrint('❌ Audio Service init failed: $e');
    debugPrint('Stack: $st');
    // Emergency fallback - return BackgroundAudioHandler as AudioHandler
    return BackgroundAudioHandler();
  }
}

void _runFallbackApp() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off, size: 64, color: Colors.white),
              SizedBox(height: 20),
              Text('I Music', style: TextStyle(fontSize: 24, color: Colors.white)),
              SizedBox(height: 10),
              Text('Failed to initialize\nPlease restart',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    ),
  );
}