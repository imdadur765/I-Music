// lib/screens/songs_list_screen.dart - ULTRA SMOOTH WITH PRELOADING & HIGH PERFORMANCE
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/services/background_audio_service.dart';
import 'package:i_music/services/album_art_service.dart';
import 'package:i_music/services/preload_service.dart';

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasCheckedSession = false;
  List<Song> _sortedSongs = [];
  bool _isPreloading = false;

  // ✅ PERFORMANCE: Combined cache for maximum efficiency
  final Map<int, Uint8List?> _thumbnailCache = {};
  final Set<int> _loadingThumbnails = {};

  @override
  void initState() {
    super.initState();
    _checkForRestoredSession();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Optional: Add scroll-based preloading here
    });
  }

  void _checkForRestoredSession() async {
    if (_hasCheckedSession) return;
    
    try {
      _hasCheckedSession = true;
      final audioHandler = ref.read(audioHandlerProvider) as BackgroundAudioHandler;
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final currentSong = audioHandler.currentSong;
      final isRestoring = audioHandler.isRestoringSession;
      
      if (currentSong != null && !isRestoring && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resuming: ${currentSong.title}'),
            backgroundColor: Colors.deepPurple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Session check error: $e');
    }
  }

  // ✅ COMBINED PRELOADING: Use both preload service and local cache
  void _preloadThumbnails(List<Song> songs) async {
    if (_isPreloading || songs.isEmpty) return;
    
    _isPreloading = true;
    
    // ✅ Start preloading in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Preload using service for future use
        await PreloadService().preloadAllThumbnails(songs);
        
        // Also populate local cache for immediate access
        for (final song in songs.take(50)) { // Limit to first 50 for performance
          if (!_thumbnailCache.containsKey(song.mediaStoreId)) {
            final thumbnail = await AlbumArtService.getThumbnail(
              songId: song.mediaStoreId,
              songTitle: song.title,
              artist: song.artist,
            );
            if (mounted) {
              _thumbnailCache[song.mediaStoreId] = thumbnail;
            }
          }
        }
      } catch (e) {
        debugPrint('Preloading error: $e');
      } finally {
        if (mounted) {
          setState(() => _isPreloading = false);
        }
      }
    });
  }

  // ✅ ULTRA FAST SORTING
  List<Song> _sortSongsAlphabetically(List<Song> songs) {
    return List<Song>.from(songs)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  // ✅ FALLBACK THUMBNAIL LOADING (if preload misses)
  Future<Uint8List?> _loadThumbnail(Song song) async {
    // First check preload service
    final preloaded = PreloadService().getThumbnail(song.mediaStoreId);
    if (preloaded != null) {
      _thumbnailCache[song.mediaStoreId] = preloaded;
      return preloaded;
    }

    // Then check local cache
    if (_thumbnailCache.containsKey(song.mediaStoreId)) {
      return _thumbnailCache[song.mediaStoreId];
    }

    if (_loadingThumbnails.contains(song.mediaStoreId)) {
      return null;
    }

    _loadingThumbnails.add(song.mediaStoreId);
    
    try {
      final thumbnail = await AlbumArtService.getThumbnail(
        songId: song.mediaStoreId,
        songTitle: song.title,
        artist: song.artist,
      );
      
      if (mounted) {
        _thumbnailCache[song.mediaStoreId] = thumbnail;
      }
      
      return thumbnail;
    } finally {
      _loadingThumbnails.remove(song.mediaStoreId);
    }
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Row(
        children: [
          Icon(Icons.music_note, color: Colors.deepPurple, size: 28),
          SizedBox(width: 12),
          Text(
            'I Music',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      elevation: 0,
      pinned: true,
      floating: true,
      // ❌ REMOVED: No automatic back button handling here
    );
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading Your Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 60, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Unable to Load Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.refresh(songsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_off, size: 80, color: Colors.deepPurple),
                SizedBox(height: 20),
                Text(
                  'No Music Found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your music library is empty',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: null,
                  style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(Colors.deepPurple),
                    padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  ),
                  child: Text(
                    'Scan for Music',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) return _buildEmptyState();

    // ✅ PERFORMANCE: Cache sorted songs and preload thumbnails
    if (_sortedSongs.isEmpty || _sortedSongs.length != songs.length) {
      _sortedSongs = _sortSongsAlphabetically(songs);
      _preloadThumbnails(songs);
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(),
        
        // Header with stats
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.library_music, color: Colors.deepPurple.shade300, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${songs.length} Songs',
                        style: TextStyle(
                          color: Colors.deepPurple.shade300,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // ✅ Show preloading status
                if (_isPreloading)
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade300),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.deepPurple.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(Icons.shuffle, color: Colors.deepPurple.shade300),
                  onPressed: () {
                    if (songs.isNotEmpty) {
                      final randomSong = (songs.toList()..shuffle()).first;
                      _playSong(randomSong, songs);
                    }
                  },
                  tooltip: 'Shuffle All',
                ),
              ],
            ),
          ),
        ),
        
        // ✅ ULTRA SMOOTH HIGH QUALITY Song List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = _sortedSongs[index];
              return _HighQualitySongListItem(
                key: ValueKey('song_${song.id}_$index'),
                song: song,
                songs: _sortedSongs,
                thumbnailCache: _thumbnailCache,
                loadThumbnail: _loadThumbnail,
                onTap: () => _playSong(song, _sortedSongs),
              );
            },
            childCount: _sortedSongs.length,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    // ❌ REMOVED: No PopScope or WillPopScope here
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: songsAsync.when(
          loading: () => _buildLoadingState(),
          error: (error, stack) => _buildErrorState(error),
          data: (songs) => _buildSongsList(songs),
        ),
      ),
    );
  }

  Future<void> _playSong(Song song, List<Song> songs) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider) as BackgroundAudioHandler;
      ref.read(currentPlaylistProvider.notifier).state = songs;
      await audioHandler.setSong(song, songs);
    } catch (e) {
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

// ✅ ULTRA PERFORMANT LIST ITEM WITH PRELOADING SUPPORT
class _HighQualitySongListItem extends StatefulWidget {
  final Song song;
  final List<Song> songs;
  final Map<int, Uint8List?> thumbnailCache;
  final Future<Uint8List?> Function(Song) loadThumbnail;
  final VoidCallback onTap;

  const _HighQualitySongListItem({
    required super.key,
    required this.song,
    required this.songs,
    required this.thumbnailCache,
    required this.loadThumbnail,
    required this.onTap,
  });

  @override
  State<_HighQualitySongListItem> createState() => _HighQualitySongListItemState();
}

class _HighQualitySongListItemState extends State<_HighQualitySongListItem> 
    with AutomaticKeepAliveClientMixin {
  
  // ✅ CACHE THE BUILT WIDGET FOR MAXIMUM PERFORMANCE
  Widget? _cachedWidget;
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // ✅ RETURN CACHED WIDGET TO AVOID EXPENSIVE REBUILDS
    if (_cachedWidget != null) {
      return _cachedWidget!;
    }
    
    _cachedWidget = _buildHighQualityItem();
    return _cachedWidget!;
  }
  
  Widget _buildHighQualityItem() {
    return RepaintBoundary( // ✅ ISOLATE PAINTING FOR BUTTER SMOOTH PERFORMANCE
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.deepPurple.withOpacity(0.3),
            highlightColor: Colors.deepPurple.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ✅ BEAUTIFUL GRADIENT BACKGROUND
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade900.withOpacity(0.9),
                    Colors.grey.shade800.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                // ✅ PROFESSIONAL SHADOW EFFECT
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.shade700.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // ✅ HIGH QUALITY ALBUM ART WITH PRELOADING SUPPORT
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _OptimizedAlbumArt(
                      song: widget.song,
                      thumbnailCache: widget.thumbnailCache,
                      loadThumbnail: widget.loadThumbnail,
                      size: 60,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // ✅ ELEGANT SONG INFO
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.song.artist,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.song.formattedDuration,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // ✅ BEAUTIFUL PLAY BUTTON
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ OPTIMIZED ALBUM ART WITH PRELOADING & SMOOTH ANIMATIONS
class _OptimizedAlbumArt extends StatefulWidget {
  final Song song;
  final Map<int, Uint8List?> thumbnailCache;
  final Future<Uint8List?> Function(Song) loadThumbnail;
  final double size;

  const _OptimizedAlbumArt({
    required this.song,
    required this.thumbnailCache,
    required this.loadThumbnail,
    required this.size,
  });

  @override
  State<_OptimizedAlbumArt> createState() => _OptimizedAlbumArtState();
}

class _OptimizedAlbumArtState extends State<_OptimizedAlbumArt> {
  Uint8List? _cachedThumbnail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  void _loadThumbnail() async {
    // ✅ FIRST CHECK PRELOAD SERVICE FOR INSTANT LOADING
    final preloadedThumbnail = PreloadService().getThumbnail(widget.song.mediaStoreId);
    if (preloadedThumbnail != null) {
      if (mounted) {
        setState(() => _cachedThumbnail = preloadedThumbnail);
      }
      return;
    }

    // ✅ THEN CHECK LOCAL CACHE
    if (_cachedThumbnail != null) return;
    
    final cached = widget.thumbnailCache[widget.song.mediaStoreId];
    if (cached != null) {
      if (mounted) {
        setState(() => _cachedThumbnail = cached);
      }
      return;
    }

    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final thumbnail = await widget.loadThumbnail(widget.song);
      if (mounted) {
        setState(() {
          _cachedThumbnail = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: _cachedThumbnail != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _cachedThumbnail!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                cacheWidth: (widget.size * 2).toInt(),
                cacheHeight: (widget.size * 2).toInt(),
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // ✅ SMOOTH FADE-IN ANIMATION
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder();
                },
              ),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade800,
            Colors.grey.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.grey.shade600,
        size: widget.size * 0.4,
      ),
    );
  }
}