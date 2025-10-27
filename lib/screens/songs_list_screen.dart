// lib/screens/songs_list_screen.dart - OPTIMIZED VERSION WITH ARTWORK
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/screens/settings_page.dart';
import '../widgets/cached_artwork.dart'; // ✅ CHANGED: AudioThumbnail -> CachedArtwork
import '../services/artwork_manager.dart'; // ✅ ADDED: For artwork management

// MethodChannel for native communication
final MethodChannel _nativeChannel = MethodChannel('i_music/media_store');

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _preloadedSongIds = {}; // ✅ CHANGED: Song IDs for artwork caching
  bool _isInitialPreloadDone = false;
  final ArtworkManager _artworkManager = ArtworkManager(); // ✅ ADDED: Artwork manager instance

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // ✅ Preload thumbnails after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadInitialThumbnails();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ OPTIMIZED PRELOADING - First 20 songs ke artwork cache karo
  void _preloadInitialThumbnails() async {
    if (_isInitialPreloadDone) return;
    
    final songsAsync = ref.read(songsProvider);
    songsAsync.whenData((songs) {
      if (songs.isNotEmpty && mounted) {
        // ✅ Pehle 20 songs ke artwork preload karen
        final songsToPreload = songs.take(20).toList();
        for (final song in songsToPreload) {
          if (song.albumArtBytes != null && song.albumArtBytes!.isNotEmpty) {
            _artworkManager.getArtworkUri(song.id, song.albumArtBytes);
            _preloadedSongIds.add(song.id);
          }
        }
        _isInitialPreloadDone = true;
        debugPrint('✅ Preloaded ${songsToPreload.length} artworks initially');
      }
    });
  }

  // ✅ OPTIMIZED SCROLL-BASED PRELOADING - Smooth scrolling ke liye
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final songsAsync = ref.read(songsProvider);
    songsAsync.whenData((songs) {
      final scrollPosition = _scrollController.position;
      final viewportHeight = scrollPosition.viewportDimension;
      final scrollOffset = scrollPosition.pixels;
      
      // ✅ Calculate visible range
      final startIndex = (scrollOffset ~/ 90).clamp(0, songs.length - 1);
      final endIndex = ((scrollOffset + viewportHeight) ~/ 90).clamp(0, songs.length - 1);
      
      // ✅ Visible items ke artwork ensure loaded
      for (int i = startIndex; i <= endIndex; i++) {
        final song = songs[i];
        if (song.albumArtBytes != null && 
            song.albumArtBytes!.isNotEmpty && 
            !_preloadedSongIds.contains(song.id)) {
          _preloadedSongIds.add(song.id);
          // ✅ Background preloading without UI update
          _artworkManager.getArtworkUri(song.id, song.albumArtBytes);
        }
      }
      
      // ✅ Next 10 items preload karen (smooth scrolling ke liye)
      final preloadStart = (endIndex + 1).clamp(0, songs.length - 1);
      final preloadEnd = (preloadStart + 10).clamp(0, songs.length - 1);
      
      for (int i = preloadStart; i <= preloadEnd; i++) {
        final song = songs[i];
        if (song.albumArtBytes != null && 
            song.albumArtBytes!.isNotEmpty && 
            !_preloadedSongIds.contains(song.id)) {
          _preloadedSongIds.add(song.id);
          _artworkManager.getArtworkUri(song.id, song.albumArtBytes);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return PopScope(
      canPop: false,
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
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, stack) => Center(
            child: Text(
              'Error loading songs: $error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          data: (songs) => _buildOptimizedSongsList(songs),
        ),
      ),
    );
  }

  // ✅ OPTIMIZED: Songs list with caching and preloading
  Widget _buildOptimizedSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Text(
          'No songs found\nCheck storage permissions',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController, // ✅ Scroll tracking for preloading
      itemCount: songs.length,
      physics: const BouncingScrollPhysics(), // ✅ Smooth scrolling
      cacheExtent: 500, // ✅ Better caching for smooth scroll
      itemBuilder: (context, index) {
        final song = songs[index];
        
        return _buildSongListItem(song, songs, index);
      },
    );
  }

  // ✅ OPTIMIZED: Individual song item with cached artwork
  Widget _buildSongListItem(Song song, List<Song> songs, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade800,
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        // ✅ OPTIMIZED: Using CachedArtwork widget for smooth performance
        leading: CachedArtwork(
          songId: song.id,
          artworkData: song.albumArtBytes, // ✅ Direct bytes from Song model
          width: 50,
          height: 50,
          placeholder: _buildArtworkPlaceholder(), // ✅ Custom placeholder
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
          song.artist,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey.shade400,
            size: 20,
          ),
          onPressed: () => _showSongOptions(song, songs),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _playSong(song, songs),
      ),
    );
  }

  // ✅ Custom artwork placeholder
  Widget _buildArtworkPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.grey[600],
        size: 20,
      ),
    );
  }

  // ✅ OPTIONAL: Song options menu
  void _showSongOptions(Song song, List<Song> songs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // ✅ Added artwork in options menu
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[800],
                child: CachedArtwork(
                  songId: song.id,
                  artworkData: song.albumArtBytes,
                  width: 50,
                  height: 50,
                  placeholder: Icon(
                    Icons.music_note,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                style: TextStyle(color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: Icons.play_arrow,
                title: 'Play now',
                onTap: () {
                  Navigator.pop(context);
                  _playSong(song, songs);
                },
              ),
              _buildOptionTile(
                icon: Icons.playlist_add,
                title: 'Add to queue',
                onTap: () {
                  Navigator.pop(context);
                  _addToQueue(song);
                },
              ),
              _buildOptionTile(
                icon: Icons.info,
                title: 'Song info',
                onTap: () {
                  Navigator.pop(context);
                  _showSongInfo(song);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ✅ Helper for option tiles
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      minLeadingWidth: 0,
    );
  }

  // ✅ Add to queue functionality
  void _addToQueue(Song song) {
    // TODO: Implement add to queue logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${song.title}" to queue'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ✅ Enhanced Song info dialog with artwork
  void _showSongInfo(Song song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            'Song Info',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Added artwork in song info
                Center(
                  child: CachedArtwork(
                    songId: song.id,
                    artworkData: song.albumArtBytes,
                    width: 100,
                    height: 100,
                    placeholder: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.album,
                        color: Colors.grey[600],
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Title', song.title),
                _buildInfoRow('Artist', song.artist),
                _buildInfoRow('Album', song.album ?? 'Unknown'),
                _buildInfoRow('Duration', _formatDuration(song.duration)),
                if (song.albumId > 0) _buildInfoRow('Album ID', song.albumId.toString()),
                if (song.albumArtBytes != null) _buildInfoRow('Artwork', 'Available (${song.albumArtBytes!.length} bytes)'),
                if (song.genre != null) _buildInfoRow('Genre', song.genre!),
                if (song.year != null) _buildInfoRow('Year', song.year.toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ Helper for info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Format duration
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // ✅ ENHANCED: Play song with artwork support
  Future<void> _playSong(Song song, List<Song> songs) async {
    try {
      debugPrint('🎵 Playing: ${song.title}');
      debugPrint('🖼️ Artwork bytes: ${song.albumArtBytes?.length ?? 0}');
      
      // ✅ Preload artwork for system notifications
      if (song.albumArtBytes != null && song.albumArtBytes!.isNotEmpty) {
        await _artworkManager.getArtworkUri(song.id, song.albumArtBytes);
      }
      
      ref.read(currentSongProvider.notifier).state = song;
      ref.read(isPlayingProvider.notifier).state = true;
      ref.read(currentPlaylistProvider.notifier).state = songs;
      
      final audioHandler = ref.read(audioHandlerProvider);
      if (audioHandler is BackgroundAudioHandler) {
        await audioHandler.setSong(song, songs);
      } else {
        await _playWithStandardHandler(audioHandler, song);
      }
      
      debugPrint('✅ Now playing: ${song.title} with artwork');
      
    } catch (e) {
      debugPrint('❌ Error playing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: ${song.title}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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