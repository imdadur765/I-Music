// lib/screens/songs_list_screen.dart - WITH SESSION RESTORATION DETECTION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/services/album_art_service.dart';
import 'package:i_music/services/session_manager.dart'; // ✅ ADD THIS IMPORT

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
  bool _hasCheckedSession = false; // ✅ ADD THIS

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    
    // ✅ ADD SESSION CHECK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRestoredSession();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    // Future enhancement for smart loading
  }

  // ✅ ADD SESSION RESTORATION CHECK
  void _checkForRestoredSession() async {
    if (_hasCheckedSession) return;
    
    try {
      _hasCheckedSession = true;
      debugPrint('🎵 Checking for restored session...');
      
      final audioHandler = ref.read(audioHandlerProvider) as BackgroundAudioHandler;
      
      // Wait a bit for restoration to complete
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final currentSong = audioHandler.currentSong;
      final isRestoring = audioHandler.isRestoringSession;
      
      debugPrint('🎵 Session Check - Current Song: ${currentSong?.title}');
      debugPrint('🎵 Session Check - Is Restoring: $isRestoring');
      debugPrint('🎵 Session Check - Queue Length: ${audioHandler.currentQueue.length}');
      
      // If session was restored and we have a current song
      if (currentSong != null && !isRestoring && mounted) {
        debugPrint('✅ RESTORED SESSION DETECTED: ${currentSong.title}');
        
        // Show restoration message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resuming: ${currentSong.title}'),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Force UI refresh
        setState(() {});
      } else {
        debugPrint('📭 No restored session found');
      }
      
    } catch (e) {
      debugPrint('❌ Session check error: $e');
    }
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
    
    // ✅ INITIALIZE SESSION MANAGER
    ref.watch(sessionManagerProvider);

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
          actions: const [
            
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

  // ✅ FIXED: Using only StreamProvider approach
  Future<void> _playSong(Song song, List<Song> songs) async {
    try {
      debugPrint('🎵 [_playSong] STARTING FRESH: ${song.title}');
      
      // ✅ STEP 1: Get audio handler
      final audioHandler = ref.read(audioHandlerProvider) as BackgroundAudioHandler;
      
      // ✅ STEP 2: Set current playlist (only StateProvider we're using)
      ref.read(currentPlaylistProvider.notifier).state = songs;
      
      debugPrint('✅ [_playSong] Playlist set for fresh start');
      
      // ✅ STEP 3: Call setSong for fresh playback
      // Audio service will automatically update the StreamProviders
      await audioHandler.setSong(song, songs);
      
      debugPrint('✅ [_playSong] COMPLETED: ${song.title} playing FRESH');
      
    } catch (e) {
      debugPrint('❌ [_playSong] ERROR: $e');
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
        color: const Color.fromRGBO(33, 33, 33, 0.5),
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
          color: Colors.purple[300],
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
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