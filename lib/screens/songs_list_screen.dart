// lib/screens/songs_list_screen.dart - ONLY HERE APP MINIMIZE
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/screens/settings_page.dart';

// MethodChannel for native communication
final MethodChannel _nativeChannel = MethodChannel('i_music/media_store');

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    // ✅ FIXED: Use PopScope instead of deprecated WillPopScope
    return PopScope(
      canPop: false, // Important: manually handle back button
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          debugPrint('🎯 Back button on SongsListScreen - MINIMIZING APP');
          try {
            await _nativeChannel.invokeMethod('minimizeApp');
          } catch (e) {
            debugPrint('❌ Error minimizing app: $e');
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('I Music', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
        body: songsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Error loading songs', style: TextStyle(color: Colors.white)),
          ),
          data: (songs) => _buildSongsList(songs),
        ),
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Text('No songs found', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        
        return ListTile(
          leading: const Icon(Icons.music_note, color: Colors.white),
          title: Text(song.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(song.artist, style: const TextStyle(color: Colors.white54)),
          onTap: () => _playSong(song, songs),
        );
      },
    );
  }

  Future<void> _playSong(Song song, List<Song> songs) async {
    try {
      debugPrint('🎵 Playing: ${song.title}');
      
      ref.read(currentSongProvider.notifier).state = song;
      ref.read(isPlayingProvider.notifier).state = true;
      ref.read(currentPlaylistProvider.notifier).state = songs;
      
      final audioHandler = ref.read(audioHandlerProvider);
      if (audioHandler is BackgroundAudioHandler) {
        await audioHandler.setSong(song, songs);
      } else {
        await _playWithStandardHandler(audioHandler, song);
      }
      
      debugPrint('✅ Now playing: ${song.title}');
      
    } catch (e) {
      debugPrint('❌ Error playing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: ${song.title}')),
        );
      }
    }
  }

  Future<void> _playWithStandardHandler(AudioHandler handler, Song song) async {
    try {
      await handler.stop();
      await handler.play();
      debugPrint('✅ Playing with standard AudioHandler: ${song.title}');
    } catch (e) {
      debugPrint('❌ Error with standard handler: $e');
      rethrow;
    }
  }
}