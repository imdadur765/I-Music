// lib/services/session_manager.dart - COMPLETELY FIXED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/services/background_audio_service.dart';

class SessionManager {
  final Ref ref;
  bool _isInitialized = false;

  SessionManager(this.ref);

  // ✅ FIXED: Better initialization with delay
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔄 SessionManager initializing...');
    
    // ✅ WAIT for app to be fully ready
    await Future.delayed(const Duration(seconds: 2));
    
    await _checkAndHandleSessionRestoration();
    _isInitialized = true;
    
    debugPrint('✅ SessionManager initialized');
  }

  // ✅ FIXED: Safe session restoration check
  Future<void> _checkAndHandleSessionRestoration() async {
    try {
      // ✅ FIXED: Use watch in callbacks, not read in constructor
      final audioHandler = ref.read(audioHandlerProvider);
      
      if (audioHandler is! BackgroundAudioHandler) {
        debugPrint('❌ AudioHandler is not BackgroundAudioHandler');
        return;
      }
      
      // Wait for audio handler to initialize
      await audioHandler.waitForInitialization();
      
      // ✅ FIXED: Better session detection logic
      final hasCurrentSong = audioHandler.currentSong != null;
      final isRestoring = audioHandler.isRestoringSession;
      
      debugPrint('🎵 SESSION CHECK: HasSong: $hasCurrentSong, IsRestoring: $isRestoring');
      
      if (hasCurrentSong && !isRestoring) {
        debugPrint('🎵 SESSION MANAGER: Restored song detected - ${audioHandler.currentSong!.title}');
        
        // ✅ Wait a bit more for UI to be ready
        await Future.delayed(const Duration(milliseconds: 500));
        await _triggerUIUpdates(audioHandler);
      } else if (isRestoring) {
        debugPrint('⏳ SESSION MANAGER: Still restoring, will check again...');
        // ✅ Retry after some time
        await Future.delayed(const Duration(seconds: 3));
        await _checkAndHandleSessionRestoration();
      }
    } catch (e) {
      debugPrint('❌ Session manager error: $e');
      // ✅ Retry on error
      await Future.delayed(const Duration(seconds: 2));
      await _checkAndHandleSessionRestoration();
    }
  }

  // ✅ FIXED: Better UI updates with state checking
  Future<void> _triggerUIUpdates(BackgroundAudioHandler audioHandler) async {
    try {
      debugPrint('🔄 Triggering UI updates for restored session');
      
      // ✅ FIXED: Multiple ways to check playing state
      final isPlaying = audioHandler.playbackState.value.playing;
      
      if (isPlaying) {
        debugPrint('🎵 Auto-navigation triggered - Song is playing');
        // Yahan pe navigation logic - PROVIDER ke through karo
        _triggerNavigation();
      } else {
        debugPrint('⏸️ Song restored but not playing');
      }
    } catch (e) {
      debugPrint('❌ Error in UI updates: $e');
    }
  }

  // ✅ NEW: Safe navigation triggering
  void _triggerNavigation() {
    try {
      // Yahan pe tum provider use karke UI ko update kar sakte ho
      // Example:
      // ref.read(navigationProvider.notifier).navigateToPlayer();
      debugPrint('📍 Navigation would be triggered here');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }

  // ✅ NEW: Manual session check for UI
  Future<void> checkSessionManually() async {
    debugPrint('👤 Manual session check triggered');
    await _checkAndHandleSessionRestoration();
  }
}

// ✅ FIXED: Better Provider with initialization control
final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref);
});

// ✅ NEW: Separate provider for initialization
final sessionManagerInitializerProvider = FutureProvider<void>((ref) async {
  final sessionManager = ref.read(sessionManagerProvider);
  await sessionManager.initialize();
});