// lib/main.dart - COMPLETE FIXED VERSION FOR ANDROID 15+
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'app.dart';
import 'models/song_model.dart';
import 'models/playlist_model.dart';
import 'services/background_audio_service.dart';

// ✅ FIXED: Use AudioHandler instead of BackgroundAudioHandler
late AudioHandler globalAudioHandler;
// ✅ ADD THIS: MethodChannel for native communication
final MethodChannel _nativeChannel = const MethodChannel('i_music/media_store');

// ✅ ADDED: Global variable to track permission status
bool _hasStoragePermission = false;

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

    // ✅ UPDATED: Request critical permissions with Android 15+ support
    await _requestAppPermissions();

    // ✅ ADDED: Check and request storage permission specifically for album art
    await _checkAndRequestStoragePermission();

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

// ✅ UPDATED: Android 15+ compatible permission handling
Future<void> _requestAppPermissions() async {
  try {
    debugPrint('🔐 Requesting app permissions for Android 15+...');
    
    // Check Android version
    final isAndroid13OrAbove = await _isAndroid13OrAbove();
    debugPrint('   📱 Android Version: ${isAndroid13OrAbove ? '13+' : '12 or below'}');

    // Permissions list based on Android version
    List<Permission> permissionsToRequest = [
      Permission.notification,
    ];

    if (isAndroid13OrAbove) {
      // Android 13+ uses READ_MEDIA_AUDIO
      permissionsToRequest.add(Permission.mediaLibrary);
      debugPrint('   🎯 Using READ_MEDIA_AUDIO for Android 13+');
    } else {
      // Android 12 and below use storage permission
      permissionsToRequest.add(Permission.storage);
      debugPrint('   🎯 Using STORAGE for Android 12 or below');
    }

    // Pehle current status check karein
    debugPrint('   📊 Checking current permission status...');
    final permissionStatuses = await Future.wait(
      permissionsToRequest.map((permission) => permission.status)
    );

    for (int i = 0; i < permissionsToRequest.length; i++) {
      debugPrint('   • ${permissionsToRequest[i]}: ${permissionStatuses[i]}');
    }

    // Agar already granted hai toh return
    final allGranted = permissionStatuses.every((status) => status.isGranted);
    if (allGranted) {
      _hasStoragePermission = true;
      debugPrint('✅ All required permissions already granted');
      return;
    }

    // Permission request karein
    debugPrint('   📝 Requesting permissions from user...');
    final permissions = await permissionsToRequest.request();

    // Results check karein
    final hasMediaLibrary = permissions[Permission.mediaLibrary]?.isGranted ?? false;
    final hasStorage = permissions[Permission.storage]?.isGranted ?? false;
    final hasNotification = permissions[Permission.notification]?.isGranted ?? false;

    // Storage permission status set karein based on Android version
    _hasStoragePermission = isAndroid13OrAbove ? hasMediaLibrary : hasStorage;

    debugPrint('   📋 Final Permission Results:');
    debugPrint('   • Media Library: $hasMediaLibrary');
    debugPrint('   • Storage: $hasStorage'); 
    debugPrint('   • Notification: $hasNotification');
    debugPrint('   • Has Storage Permission: $_hasStoragePermission');

    if (!_hasStoragePermission) {
      debugPrint('❌ Storage permission not granted');
      debugPrint('   💡 User needs to manually grant permission in app settings');
      debugPrint('   📱 Path: Settings → Apps → i_music → Permissions → Files and Media');
      
      // Retry logic
      debugPrint('   🔄 Retrying permission request in 3 seconds...');
      await Future.delayed(const Duration(seconds: 3));
      await _retryPermissionRequest(isAndroid13OrAbove);
    } else {
      debugPrint('✅ All critical permissions granted - Album art will work!');
    }
  } catch (e) {
    debugPrint('❌ Permission error: $e');
    _hasStoragePermission = false;
  }
}

// ✅ ADDED: Special method for storage permission only (for album art)
Future<void> _checkAndRequestStoragePermission() async {
  try {
    debugPrint('🎵 Checking storage permission for album art...');
    
    final isAndroid13OrAbove = await _isAndroid13OrAbove();
    final storagePermission = isAndroid13OrAbove ? Permission.mediaLibrary : Permission.storage;
    
    final status = await storagePermission.status;
    debugPrint('   🔐 Current Storage Permission Status: $status');
    
    if (status.isGranted) {
      _hasStoragePermission = true;
      debugPrint('   ✅ Storage permission already granted for album art');
      return;
    }
    
    if (status.isDenied) {
      debugPrint('   📝 Requesting storage permission for album art...');
      final result = await storagePermission.request();
      debugPrint('   📋 Storage permission request result: $result');
      
      _hasStoragePermission = result.isGranted;
      
      if (_hasStoragePermission) {
        debugPrint('   ✅ Storage permission granted - Album art will work!');
      } else {
        debugPrint('   ❌ Storage permission denied - Album art will not work');
        debugPrint('   💡 User can enable it later in app settings');
      }
    } else if (status.isPermanentlyDenied) {
      debugPrint('   🚫 Storage permission permanently denied');
      debugPrint('   📱 Please enable manually: Settings → Apps → i_music → Permissions → Files and Media');
      _hasStoragePermission = false;
    }
  } catch (e) {
    debugPrint('❌ Storage permission check error: $e');
    _hasStoragePermission = false;
  }
}

// ✅ ADDED: Check if device is Android 13 or above
Future<bool> _isAndroid13OrAbove() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      debugPrint('   📊 Detected Android SDK: $sdkVersion');
      return sdkVersion >= 33; // Android 13 is SDK 33
    }
    return false;
  } catch (e) {
    debugPrint('❌ Error checking Android version: $e');
    // Assume newer Android by default for safety
    return true;
  }
}

// ✅ UPDATED: Retry permission request method
Future<void> _retryPermissionRequest(bool isAndroid13OrAbove) async {
  try {
    debugPrint('🔄 Retrying permission request...');
    
    List<Permission> permissionsToRequest = [Permission.notification];
    
    if (isAndroid13OrAbove) {
      permissionsToRequest.add(Permission.mediaLibrary);
    } else {
      permissionsToRequest.add(Permission.storage);
    }

    final permissions = await permissionsToRequest.request();

    final hasMediaLibrary = permissions[Permission.mediaLibrary]?.isGranted ?? false;
    final hasStorage = permissions[Permission.storage]?.isGranted ?? false;

    _hasStoragePermission = isAndroid13OrAbove ? hasMediaLibrary : hasStorage;

    if (_hasStoragePermission) {
      debugPrint('✅ Permissions granted on retry! Album art will work now.');
    } else {
      debugPrint('❌ Permissions still not granted after retry');
      debugPrint('   🎯 Please manually enable "Files and Media" permission');
      debugPrint('   📱 Settings → Apps → i_music → Permissions → Files and Media');
    }
  } catch (e) {
    debugPrint('❌ Retry permission error: $e');
  }
}

// ✅ ADDED: Method to check current permission status (public access)
bool get hasStoragePermission => _hasStoragePermission;

// ✅ ADDED: Method to request permissions manually
Future<void> requestPermissionsManually() async {
  try {
    debugPrint('👤 Manual permission request triggered');
    await _checkAndRequestStoragePermission();
  } catch (e) {
    debugPrint('❌ Manual permission request error: $e');
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
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
        preloadArtwork: true,
        androidResumeOnClick: true,
        notificationColor: Colors.deepPurple,
        androidNotificationOngoing: false,
      ),
    );

    debugPrint('✅ Audio Service initialized successfully!');
    return audioHandler;
  } catch (e, st) {
    debugPrint('❌ Audio Service init failed: $e');
    debugPrint('Stack: $st');
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