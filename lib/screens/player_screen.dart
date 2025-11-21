// lib/screens/player_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/models/song_model.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/widgets/album_art_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:i_music/services/lyrics_cache_service.dart';
import 'package:i_music/services/file_picker_service.dart';
import 'package:i_music/services/album_art_service.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  double _currentPosition = 0.0;
  bool _isDragging = false;
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late AnimationController _rotationController;

  // Lyrics panel variables
  bool _showLyricsPanel = false;
  String _lyricsText = "Lyrics content will appear here";
  bool _isLoadingLyrics = false;

  // Song list panel
  bool _showSongList = false;

  // ✅ ULTIMATE PERFORMANCE FIXES
  late Timer _progressTimer;
  MediaItem? _currentMediaItem;
  PlaybackState? _currentPlaybackState;
  bool _isPlaying = false;
  Song? _currentSong;
  
  // ✅ NEW: Optimized list variables (SAME AS SONGS LIST SCREEN)
  final _scrollController = ScrollController();
  List<Song> _cachedSongs = [];
  bool _isSongListLoading = false;
  
  // ✅ NEW: Cache for album arts to prevent rebuilds
  final _albumArtCache = <String, ImageProvider>{};

  @override
  void initState() {
    super.initState();

    _currentDuration = Duration.zero;
    _totalDuration = Duration.zero;

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _setupAudioListeners();
    
    // ✅ OPTIMIZED: Less frequent progress updates
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted && !_isDragging) {
        _updateProgress();
      }
    });
  }

  void _setupAudioListeners() {
    main_app.globalAudioHandler.mediaItem.listen((mediaItem) {
      if (mounted && mediaItem != _currentMediaItem) {
        setState(() {
          _currentMediaItem = mediaItem;
          if (mediaItem != null) {
            _currentSong = _songFromMediaItem(mediaItem);
            _totalDuration = mediaItem.duration ?? Duration.zero;
          }
        });
      }
    });

    main_app.globalAudioHandler.playbackState.listen((playbackState) {
      if (mounted) {
        final wasPlaying = _isPlaying;
        _isPlaying = playbackState.playing;
        
        if (wasPlaying != _isPlaying || playbackState != _currentPlaybackState) {
          setState(() {
            _currentPlaybackState = playbackState;
          });
          _handlePlaybackState(_isPlaying);
        }
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _progressTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final playbackState = _currentPlaybackState ?? main_app.globalAudioHandler.playbackState.value;
    final position = playbackState.position;
    
    if (_currentMediaItem != null) {
      final totalMs = _currentMediaItem!.duration?.inMilliseconds ?? 0;
      if (totalMs > 0) {
        final newPosition = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;
        if ((newPosition - _currentPosition).abs() > 0.001 || !_isDragging) {
          setState(() {
            _currentDuration = position;
            if (!_isDragging) {
              _currentPosition = newPosition;
            }
          });
        }
      }
    }
  }

  void _seekToPosition(double value) {
    final clampedValue = value.clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _currentPosition = clampedValue;
    });

    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs > 0) {
      final newPosition = Duration(milliseconds: (clampedValue * totalMs).round());
      main_app.globalAudioHandler.seek(newPosition);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final newPosition = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    setState(() {
      _currentPosition = newPosition;
    });
  }

  void _handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final double newPosition = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    _seekToPosition(newPosition);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Song _songFromMediaItem(MediaItem mediaItem) {
    final extras = mediaItem.extras;
    if (extras != null && extras['song_object'] is Song) {
      return extras['song_object'] as Song;
    }

    return Song(
      id: mediaItem.id,
      uri: (mediaItem.extras?['uri'] ?? mediaItem.id).toString(),
      title: mediaItem.title,
      artist: mediaItem.artist ?? 'Unknown Artist',
      album: mediaItem.album,
      duration: mediaItem.duration?.inMilliseconds ?? 0,
      albumArt: mediaItem.artUri?.toString(),
      mediaStoreId: int.tryParse(mediaItem.extras?['mediaStoreId']?.toString() ?? '') ?? 0,
      genre: mediaItem.genre,
      trackNumber: (mediaItem.extras?['trackNumber'] is int) 
          ? mediaItem.extras!['trackNumber'] as int 
          : 0,
      year: (mediaItem.extras?['year'] is int) 
          ? mediaItem.extras!['year'] as int 
          : 0,
      composer: mediaItem.extras?['composer']?.toString(),
      playCount: 0,
      lastPlayed: DateTime.now(),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );
  }

  void _handlePlaybackState(bool isPlaying) {
    if (isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  // ✅ FILE PICKER METHODS
  Future<void> _importAudioFiles() async {
    try {
      final files = await FilePickerService.pickAudioFiles();
      if (files.isNotEmpty) {
        _showImportSuccessDialog(files.length);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio files selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing files: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importLyricsFromFile() async {
    try {
      final lyricsText = await FilePickerService.pickLyricsTextFile();
      if (lyricsText != null && lyricsText.isNotEmpty) {
        final mediaItem = _currentMediaItem;
        if (mediaItem != null) {
          final song = _songFromMediaItem(mediaItem);
          await LyricsCacheService.cacheLyrics(song.title, song.artist, lyricsText);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lyrics imported successfully'),
              backgroundColor: Colors.green,
            ),
          );
          if (_showLyricsPanel) {
            setState(() {
              _lyricsText = lyricsText;
            });
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No lyrics found in selected file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing lyrics: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImportSuccessDialog(int fileCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Files Imported'),
        content: Text('Successfully imported $fileCount audio files'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.audio_file, color: Colors.white),
              title: const Text('Import Audio Files', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _importAudioFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lyrics, color: Colors.white),
              title: const Text('Import Lyrics from File', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _importLyricsFromFile();
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ULTRA-OPTIMIZED SONG LIST METHODS (LIKE SONGS LIST SCREEN)
  void _toggleSongList() {
    setState(() {
      _showSongList = !_showSongList;
      if (_showSongList) {
        _precacheSongList();
      }
    });
  }

  // ✅ NEW: Pre-cache song list data like SongsListScreen
  void _precacheSongList() {
    if (_isSongListLoading) return;
    
    _isSongListLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final songs = ref.read(songsProvider).value ?? [];
        if (songs.isNotEmpty) {
          setState(() {
            _cachedSongs = List.from(songs);
          });
          
          // ✅ Pre-cache album arts in background - EXACTLY LIKE SONGS LIST SCREEN
          await _precacheAlbumArts(songs);
        }
      } catch (e) {
        debugPrint('Precache error: $e');
      } finally {
        if (mounted) {
          setState(() => _isSongListLoading = false);
        }
      }
    });
  }

  // ✅ NEW: Pre-cache album arts to prevent jank - SAME AS SONGS LIST SCREEN
  Future<void> _precacheAlbumArts(List<Song> songs) async {
    for (final song in songs.take(50)) { // Limit to first 50 for performance
      if (!_albumArtCache.containsKey(song.id)) {
        try {
          // Use the same caching logic as your songs list screen
          final cachedThumbnail = await AlbumArtService.getThumbnail(
            songId: song.mediaStoreId,
            songTitle: song.title,
            artist: song.artist,
          );
          if (mounted && cachedThumbnail != null) {
            _albumArtCache[song.id] = MemoryImage(cachedThumbnail);
          }
        } catch (e) {
          debugPrint('Album art cache error for ${song.title}: $e');
        }
      }
    }
  }

  Widget _buildSongListPanel() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.black,
            padding: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 25),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _toggleSongList,
                ),
                const SizedBox(width: 30),
                const Expanded(
                  child: Text(
                    'Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Now Playing Section
          if (_currentMediaItem != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                border: const Border(
                  bottom: BorderSide(color: Colors.deepPurple, width: 1),
                ),
              ),
              child: _buildNowPlayingSection(_currentMediaItem!),
            ),
          
          // ✅ OPTIMIZED: Use cached songs for immediate display
          Expanded(
            child: _buildOptimizedSongList(),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Ultra-optimized song list using cached data
  Widget _buildOptimizedSongList() {
    // ✅ FIRST: Try to use cached songs for instant loading
    if (_cachedSongs.isNotEmpty && !_isSongListLoading) {
      final currentSongId = _currentSong?.id;
      return _OptimizedSongListView(
        songs: _cachedSongs,
        currentSongId: currentSongId,
        scrollController: _scrollController,
        buildItem: _buildSongListItem,
      );
    }

    // ✅ FALLBACK: Use provider if cache is empty
    return Consumer(
      builder: (context, ref, child) {
        final songsAsync = ref.watch(songsProvider);
        
        return songsAsync.when(
          loading: () => const _SongListLoading(),
          error: (error, stack) => _SongListError(
            onRetry: () => ref.refresh(songsProvider),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return _buildEmptyState();
            }
            
            // Cache the songs for next time
            if (_cachedSongs.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _cachedSongs = List.from(songs);
                });
                _precacheAlbumArts(songs);
              });
            }
            
            return _buildOptimizedSongListFromData(songs);
          },
        );
      },
    );
  }

  // ✅ NEW: Helper method for data-based song list
  Widget _buildOptimizedSongListFromData(List<Song> songs) {
    final currentSongId = _currentSong?.id;
    
    return _OptimizedSongListView(
      songs: songs,
      currentSongId: currentSongId,
      scrollController: _scrollController,
      buildItem: _buildSongListItem,
    );
  }

  // ✅ ULTRA-OPTIMIZED: Memoized song list item with caching - LIKE SONGS LIST SCREEN
  Widget _buildSongListItem(Song song, int index, bool isCurrent) {
    return _PlayerSongListItem(
      key: ValueKey('player_song_${song.id}_$index'),
      song: song,
      isCurrent: isCurrent,
      formatDuration: _formatDuration,
      albumArtCache: _albumArtCache,
      onTap: () {
        final songs = _cachedSongs.isNotEmpty ? _cachedSongs : (ref.read(songsProvider).value ?? []);
        playSong(ref, song, songs);
        _toggleSongList();
      },
    );
  }

  Widget _buildNowPlayingSection(MediaItem mediaItem) {
    final currentSong = _songFromMediaItem(mediaItem);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: NowPlayingAlbumArt(
            song: currentSong,
            size: 40,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Now Playing',
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                currentSong.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.music_note, color: Colors.deepPurple, size: 30),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            color: Colors.grey.shade600,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import audio files to get started',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _importAudioFiles,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Import Audio Files',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchLyricsForCurrentSong(Song song) async {
    if (_isLoadingLyrics) return;

    setState(() {
      _isLoadingLyrics = true;
      _lyricsText = "Checking for lyrics...";
    });

    try {
      final cachedLyrics = await LyricsCacheService.getCachedLyricsAsync(
        song.title, 
        song.artist
      );
      
      if (cachedLyrics != null && cachedLyrics.isNotEmpty) {
        setState(() {
          _lyricsText = cachedLyrics;
          _isLoadingLyrics = false;
        });
        return;
      }

      setState(() {
        _lyricsText = '''
Lyrics for "${song.title}" by ${song.artist}

Manual Lyrics Input Required

Currently, this song's lyrics are not available in our database. 
You can contribute by adding the lyrics manually through our 
user-friendly lyrics editor.

To add lyrics for this song:

1. Navigate to the song details page
2. Select the "Add Lyrics" option
3. Enter the complete lyrics text
4. Submit for community review

Coming Soon:
• Licensed lyrics database integration
• Automated lyrics synchronization
• Expanded song library

Thank you for helping us build a comprehensive lyrics database.
Your contribution is valuable to the community.

For any assistance, please contact support
Email: imdadurrahman488@gmail.com

For quick contact, copy the email above or use the "Contact Support" button (opens your mail client).
''';
        _isLoadingLyrics = false;
      });

    } catch (e) {
      setState(() {
        _lyricsText = "Unable to load lyrics at this time.\n\nPlease try again later or add lyrics manually.";
        _isLoadingLyrics = false;
      });
    }
  }

  // UI COMPONENTS
  Widget _buildModernAppBar(Song song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, 
                  color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now Playing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
              onPressed: _toggleSongList,
            ),
          ),
          
          const SizedBox(width: 8),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
              onPressed: () => _showMoreOptionsMenu(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAlbumArt(Song song, bool isPlaying) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.70,
            height: MediaQuery.of(context).size.width * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.60,
                  height: MediaQuery.of(context).size.width * 0.60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: NowPlayingAlbumArt(
                      song: song,
                      size: MediaQuery.of(context).size.width * 0.60,
                    ),
                  ),
                ),
              );
            },
          ),
          
          if (!isPlaying)
            Positioned(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernSongInfo(Song song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Text(
            song.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 6),
          
          Text(
            song.artist,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          if (song.album != null && song.album!.isNotEmpty)
            Text(
              song.album!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildModernProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentDuration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(_totalDuration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTapDown(details, constraints),
                onPanStart: (details) => setState(() => _isDragging = true),
                onPanUpdate: (details) => _handleDragUpdate(details, constraints),
                onPanEnd: (details) => _seekToPosition(_currentPosition),
                onPanCancel: () => _seekToPosition(_currentPosition),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      
                      AnimatedContainer(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                        height: 4,
                        width: constraints.maxWidth * (_currentPosition.isNaN ? 0.0 : _currentPosition),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5DFF), Color(0xFFE91E63)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      
                      AnimatedPositioned(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                        left: (constraints.maxWidth * (_currentPosition.isNaN ? 0.0 : _currentPosition)) - 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernControls(bool isPlaying) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            onPressed: () => debugPrint('Shuffle pressed'),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
              onPressed: () => main_app.globalAudioHandler.skipToPrevious(),
            ),
          ),
          
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5DFF), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8B5DFF),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              padding: const EdgeInsets.all(14),
              onPressed: () {
                if (isPlaying) {
                  main_app.globalAudioHandler.pause();
                } else {
                  main_app.globalAudioHandler.play();
                }
              },
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              onPressed: () => main_app.globalAudioHandler.skipToNext(),
            ),
          ),
          
          IconButton(
            icon: Icon(
              Icons.repeat_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            onPressed: () => debugPrint('Repeat pressed'),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLyricsButton(Song song) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.deepPurple.withOpacity(0.6), width: 1.5),
          ),
          elevation: 2,
        ),
        onPressed: () {
          setState(() {
            _showLyricsPanel = true;
          });
          _fetchLyricsForCurrentSong(song);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.withOpacity(0.4),
                Colors.purple.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_rounded, size: 16, color: Colors.deepPurple.shade300),
              const SizedBox(width: 6),
              const Text(
                'Lyrics',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsPanel(Song song, BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showLyricsPanel = false;
                    });
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload, color: Colors.white),
                  onPressed: _importLyricsFromFile,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: _isLoadingLyrics
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading lyrics...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900]?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Text(
                              _lyricsText,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          if (!_lyricsText.contains("Manual Lyrics Input Required"))
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    "Lyrics loaded from local storage",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_lyricsText.contains("Manual Lyrics Input Required"))
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.blue, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        "How to Add Lyrics",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "You can add lyrics for this song through the song details page or import from a text file.",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _showLyricsPanel = false;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepPurple,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: const Text(
                                            'Song Details',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _importLyricsFromFile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: const Text(
                                            'Import File',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displaySong = _currentSong;
    final isPlaying = _isPlaying;

    if (displaySong == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5DFF)),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_showLyricsPanel) {
          setState(() {
            _showLyricsPanel = false;
          });
          return false;
        }
        if (_showSongList) {
          setState(() {
            _showSongList = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A0A0A),
                      Color(0xFF1A1A2E),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              
              Column(
                children: [
                  _buildModernAppBar(displaySong),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            _buildModernAlbumArt(displaySong, isPlaying),
                            const SizedBox(height: 10),
                            _buildModernSongInfo(displaySong),
                            const SizedBox(height: 10),
                            _buildModernProgressBar(),
                            const SizedBox(height: 10),
                            _buildModernLyricsButton(displaySong),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              _buildModernControls(isPlaying),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Lyrics Panel
              if (_showLyricsPanel)
                Positioned.fill(
                  child: _buildLyricsPanel(displaySong, context),
                ),

              // Song List Panel
              if (_showSongList)
                Positioned.fill(
                  child: _buildSongListPanel(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ ULTRA-PERFORMANT PLAYER SONG LIST ITEM (Like SongsListScreen)
class _PlayerSongListItem extends StatefulWidget {
  final Song song;
  final bool isCurrent;
  final String Function(Duration) formatDuration;
  final Map<String, ImageProvider> albumArtCache;
  final VoidCallback onTap;

  const _PlayerSongListItem({
    required Key key,
    required this.song,
    required this.isCurrent,
    required this.formatDuration,
    required this.albumArtCache,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_PlayerSongListItem> createState() => _PlayerSongListItemState();
}

class _PlayerSongListItemState extends State<_PlayerSongListItem> 
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
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isCurrent 
              ? Colors.deepPurple.withOpacity(0.3)
              : Colors.grey[900]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: widget.isCurrent 
              ? Border.all(color: Colors.deepPurple.shade400, width: 1)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.deepPurple.withOpacity(0.3),
            highlightColor: Colors.deepPurple.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // ✅ OPTIMIZED ALBUM ART WITH CACHING
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[800],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _PlayerAlbumArt(
                        song: widget.song,
                        albumArtCache: widget.albumArtCache,
                        size: 50,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: widget.isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.song.artist,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  widget.isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PLAYING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Text(
                          widget.formatDuration(Duration(milliseconds: widget.song.duration)),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
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

// ✅ OPTIMIZED PLAYER ALBUM ART WITH CACHING
class _PlayerAlbumArt extends StatefulWidget {
  final Song song;
  final Map<String, ImageProvider> albumArtCache;
  final double size;

  const _PlayerAlbumArt({
    required this.song,
    required this.albumArtCache,
    required this.size,
  });

  @override
  State<_PlayerAlbumArt> createState() => _PlayerAlbumArtState();
}

class _PlayerAlbumArtState extends State<_PlayerAlbumArt> {
  ImageProvider? _cachedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAlbumArt();
  }

  void _loadAlbumArt() async {
    if (_isLoading) return;
    
    // ✅ FIRST CHECK CACHE
    if (widget.albumArtCache.containsKey(widget.song.id)) {
      if (mounted) {
        setState(() {
          _cachedImage = widget.albumArtCache[widget.song.id];
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // ✅ USE THE SAME PRELOADING TECHNIQUE AS SONGS LIST SCREEN
      final cachedThumbnail = await AlbumArtService.getThumbnail(
        songId: widget.song.mediaStoreId,
        songTitle: widget.song.title,
        artist: widget.song.artist,
      );
      
      if (mounted && cachedThumbnail != null) {
        final image = MemoryImage(cachedThumbnail);
        widget.albumArtCache[widget.song.id] = image;
        setState(() {
          _cachedImage = image;
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
    return _cachedImage != null
        ? Image(
            image: _cachedImage!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                return child;
              }
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
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

// ✅ NEW: Optimized Song List View
class _OptimizedSongListView extends StatelessWidget {
  final List<Song> songs;
  final String? currentSongId;
  final ScrollController scrollController;
  final Widget Function(Song song, int index, bool isCurrent) buildItem;

  const _OptimizedSongListView({
    Key? key,
    required this.songs,
    required this.currentSongId,
    required this.scrollController,
    required this.buildItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      // ✅ CRITICAL: Add itemExtent for maximum performance
      itemExtent: 70,
      // ✅ CRITICAL: Optimize scrolling physics
      physics: const BouncingScrollPhysics(),
      // ✅ CRITICAL: Add repaint boundaries
      addRepaintBoundaries: true,
      // ✅ CRITICAL: Add automatic keep alive
      addAutomaticKeepAlives: true,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isCurrent = currentSongId == song.id;
        return buildItem(song, index, isCurrent);
      },
    );
  }
}

// ✅ NEW: Loading Widget
class _SongListLoading extends StatelessWidget {
  const _SongListLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
      ),
    );
  }
}

// ✅ NEW: Error Widget
class _SongListError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SongListError({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Error loading songs',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}