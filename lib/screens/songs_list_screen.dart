// lib/screens/songs_list_screen.dart - OPTIMIZED WITH CACHE (CLEAN VERSION)
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/screens/settings_page.dart';
import 'package:i_music/services/album_art_service.dart';

// MethodChannel for native communication
const MethodChannel _nativeChannel = MethodChannel('i_music/media_store');

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    // Future enhancement for smart loading
  }

  void _preloadThumbnails(List<Song> songs) {
    if (_isPreloading) return;
    
    _isPreloading = true;
    debugPrint('🚀 Starting thumbnail preload for ${songs.length} songs');
    
    for (final song in songs) {
      AlbumArtService.getThumbnail(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      ).then((data) {
        if (data != null) {
          debugPrint('✅ Preloaded thumbnail for: ${song.title}');
        }
      }).catchError((e) {
        debugPrint('❌ Error preloading thumbnail for ${song.title}: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    songsAsync.whenData((songs) {
      if (songs.isNotEmpty && !_isPreloading) {
        _preloadThumbnails(songs);
      }
    });

    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading your music...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                const Text(
                  'Error loading songs',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(songsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
            const Icon(Icons.music_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No songs found',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure you have music files on your device',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(songsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
              child: const Text('Refresh', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: songs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      addAutomaticKeepAlives: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        final song = songs[index];
        
        return _OptimizedSongListItem(
          key: ValueKey(song.id),
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

class _OptimizedSongListItem extends StatefulWidget {
  final Song song;
  final List<Song> songs;
  final VoidCallback onTap;

  const _OptimizedSongListItem({
    required Key key,
    required this.song,
    required this.songs,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_OptimizedSongListItem> createState() => _OptimizedSongListItemState();
}

class _OptimizedSongListItemState extends State<_OptimizedSongListItem> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: OptimizedAlbumArtWidget(
          song: widget.song,
          size: 50.0,
          borderRadius: 8.0,
        ),
        title: Text(
          widget.song.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${widget.song.artist} • ${widget.song.formattedDuration}',
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
        onTap: widget.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class OptimizedAlbumArtWidget extends StatelessWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final bool showShadow;

  const OptimizedAlbumArtWidget({
    super.key,
    required this.song,
    this.size = 50.0,
    this.borderRadius = 8.0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: AlbumArtService.getThumbnail(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      ),
      builder: (context, snapshot) {
        Widget imageWidget;
        
        if (snapshot.hasData && snapshot.data != null) {
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: size.toInt(),
            ),
          );
        } else {
          imageWidget = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              Icons.music_note,
              color: Colors.grey[600],
              size: size * 0.4,
            ),
          );
        }

        return Container(
          width: size,
          height: size,
          decoration: showShadow
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : null,
          child: imageWidget,
        );
      },
    );
  }
}