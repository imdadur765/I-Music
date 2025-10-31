// lib/screens/songs_list_screen.dart - UPDATED WITH ALBUM ART
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/screens/settings_page.dart';
import 'package:i_music/widgets/album_art_widget.dart'; // ✅ ADDED

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
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Error loading songs',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          data: (songs) => _buildSongsList(songs),
        ),
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No songs found',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure you have music files on your device',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final song = songs[index];
        
        return _SongListItem(
          song: song,
          songs: songs,
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
          SnackBar(
            content: Text('Failed to play: ${song.title}'),
            backgroundColor: Colors.red,
          ),
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

// ✅ ADDED: Separate widget for song list item for better performance
class _SongListItem extends StatelessWidget {
  final Song song;
  final List<Song> songs;
  final VoidCallback onTap;

  const _SongListItem({
    required this.song,
    required this.songs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        // ✅ UPDATED: Using AlbumArtWidget instead of Icon
        leading: AlbumArtWidget(
          song: song,
          size: 50.0,
          borderRadius: 8.0,
          showShadow: true,
        ),
        title: Text(
          song.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${song.artist} • ${song.formattedDuration}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.play_arrow,
          color: Colors.purple.shade300,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}