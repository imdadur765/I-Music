// lib/services/session_manager.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/services/background_audio_service.dart';

class SessionManager {
  final Ref ref;

  SessionManager(this.ref);

  void initialize() {
    _checkAndHandleSessionRestoration();
  }

  void _checkAndHandleSessionRestoration() async {
    try {
      final audioHandler = ref.read(audioHandlerProvider) as BackgroundAudioHandler;
      
      // Wait for audio handler to initialize
      await audioHandler.waitForInitialization();
      
      // Check if session was restored
      if (audioHandler.currentSong != null && !audioHandler.isRestoringSession) {
        debugPrint('🎵 SESSION MANAGER: Restored song detected - ${audioHandler.currentSong!.title}');
        
        // Force UI updates here
        _triggerUIUpdates(audioHandler);
      }
    } catch (e) {
      debugPrint('❌ Session manager error: $e');
    }
  }

  void _triggerUIUpdates(BackgroundAudioHandler audioHandler) {
    debugPrint('🔄 Triggering UI updates for restored session');
    
    // ✅ FIXED: Check playing state using a different approach
    // Stream ka first value get karo ya phir direct check karo
    audioHandler.playerStateStream.first.then((playerState) {
      if (playerState.playing) {
        debugPrint('🎵 Auto-navigation triggered - Song is playing');
        // Yahan pe tum navigation kar sakte ho if needed
        // Navigator.push(...) - if you want auto navigation
      }
    }).catchError((e) {
      debugPrint('❌ Error checking player state: $e');
    });
  }
}

// Provider banao
final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref)..initialize();
});