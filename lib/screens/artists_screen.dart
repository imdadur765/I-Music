// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:audio_service/audio_service.dart';

import '../models/artist_model.dart';
import '../models/song_model.dart' as song_model;
import '../services/combined_artist_service.dart';
import '../services/local_songs_service.dart';
import '../services/background_audio_service.dart';
import '../providers/music_player_provider.dart';
import '../main.dart' as main_app;
import 'home_screen.dart';

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late CombinedArtistService _combinedService;

  List<Artist> _mainArtistList = [];
  List<Artist> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String _error = '';
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _combinedService = CombinedArtistService();
    _initializeService();
  }

  void _initializeService() async {
    _combinedService.initialize();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final artists = await _combinedService.getCombinedArtists();

      setState(() {
        _mainArtistList = artists;
        _isLoading = false;
        _isOnline = _combinedService.isOnline;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load artists: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _combinedService.refreshSpotifyData();
    await _loadArtists();
  }

  Future<void> _searchArtists(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    try {
      setState(() => _isLoading = true);

      final artists = await _combinedService.searchCombinedArtists(query);

      setState(() {
        _searchResults = artists;
        _isSearching = true;
        _isLoading = false;
        _isOnline = _combinedService.isOnline;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Search error: $e');
      }
      // Fallback: local filtering
      final filtered =
          _mainArtistList.where((artist) => artist.name.toLowerCase().contains(query.toLowerCase())).toList();

      setState(() {
        _searchResults = filtered;
        _isSearching = true;
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
    _searchFocusNode.unfocus();
  }

  // ✅ FIXED: CONVERSION FUNCTION
  song_model.Song _convertLocalSongToSong(LocalSong localSong) {
    return song_model.Song(
      id: localSong.id,
      uri: localSong.uri.isNotEmpty ? localSong.uri : "file://${localSong.path}",
      title: localSong.title,
      artist: localSong.artist,
      album: localSong.album,
      duration: localSong.duration,
      mediaStoreId: int.tryParse(localSong.id) ?? localSong.id.hashCode.abs(),
      albumArt: null,
      genre: null,
      trackNumber: null,
      year: null,
      composer: null,
      playCount: 0,
      lastPlayed: DateTime.now(),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );
  }

  List<song_model.Song> _convertLocalSongsToSongs(List<LocalSong> localSongs) {
    return localSongs.map(_convertLocalSongToSong).toList();
  }

  // ✅ FIXED: Audio Handler getter - COMPATIBLE WITH YOUR BackgroundAudioHandler
  BackgroundAudioHandler? get _audioHandler {
    try {
      final handler = main_app.globalAudioHandler;
      if (handler is BackgroundAudioHandler) {
        return handler;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Audio handler not available: $e');
      }
      return null;
    }
  }

  // ✅ FIXED: Audio service check
  Future<bool> _isAudioServiceRunning() async {
    try {
      return AudioService.running;
    } catch (e) {
      return false;
    }
  }

  // ✅ FIXED: Start Audio Service - COMPATIBLE WITH YOUR BackgroundAudioHandler
  Future<bool> _startAudioService() async {
    try {
      if (await _isAudioServiceRunning()) {
        return true;
      }

      await AudioService.start(
        backgroundTaskEntrypoint: _audioHandlerTaskEntrypoint,
        androidNotificationChannelName: 'Music Player',
        androidNotificationColor: 0xFF2196f3,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidEnableQueue: true,
      );
      
      // Wait for service to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting audio service: $e');
      }
      return false;
    }
  }

  // ✅ FIXED: Audio handler entry point - COMPATIBLE WITH YOUR BackgroundAudioHandler
  static void _audioHandlerTaskEntrypoint() async {
    AudioServiceBackground.run(() => BackgroundAudioHandler() as dynamic);
  }

  // ✅ FIXED: Play All Songs - COMPATIBLE WITH YOUR BackgroundAudioHandler
  Future<void> _playAllLocalSongs(List<LocalSong> localSongs) async {
    try {
      if (!mounted) return;
      if (localSongs.isEmpty) {
        _showSnackBar('No songs available to play', Colors.orange);
        return;
      }

      // Start audio service first
      final serviceStarted = await _startAudioService();
      if (!serviceStarted) {
        _showSnackBar('Failed to start audio service', Colors.red);
        return;
      }

      final audioHandler = _audioHandler;
      if (audioHandler == null) {
        _showSnackBar('Audio service not ready', Colors.red);
        return;
      }

      // ✅ WAIT FOR YOUR BackgroundAudioHandler TO INITIALIZE
      await audioHandler.waitForInitialization();

      // Convert to Song model for background service
      final songs = _convertLocalSongsToSongs(localSongs);

      // Use custom action to set song with queue - COMPATIBLE WITH YOUR HANDLER
      await audioHandler.customAction('setSongWithQueue', {
        'song': songs.first.toJson(),
        'queue': songs.map((s) => s.toJson()).toList(),
      });

      // Update UI state - THIS WILL TRIGGER MINI PLAYER
      ref.read(musicPlayerProvider.notifier).playPlaylist(localSongs);

      if (mounted) {
        _showSnackBar('Playing ${songs.length} songs', const Color(0xFF10B981));
      }

      if (kDebugMode) {
        print('🎵 Playing all ${songs.length} songs');
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('❌ Error playing all songs: $e');
      }
      _showSnackBar('Error playing songs: ${e.toString()}', Colors.red);
    }
  }

  // ✅ FIXED: Play Single Song - COMPATIBLE WITH YOUR BackgroundAudioHandler
  Future<void> _playLocalSong(LocalSong localSong, List<LocalSong> allSongs) async {
    try {
      if (!mounted) return;
      
      // Start audio service first
      final serviceStarted = await _startAudioService();
      if (!serviceStarted) {
        _showSnackBar('Failed to start audio service', Colors.red);
        return;
      }

      final audioHandler = _audioHandler;
      if (audioHandler == null) {
        _showSnackBar('Audio service not ready', Colors.red);
        return;
      }

      // ✅ WAIT FOR YOUR BackgroundAudioHandler TO INITIALIZE
      await audioHandler.waitForInitialization();

      // Convert all songs to Song model
      final songs = _convertLocalSongsToSongs(allSongs);
      final currentSong = _convertLocalSongToSong(localSong);

      // Find current index
      final currentIndex = songs.indexWhere((song) => song.id == currentSong.id);

      if (currentIndex != -1) {
        // Use custom action to set song with queue - COMPATIBLE WITH YOUR HANDLER
        await audioHandler.customAction('setSongWithQueue', {
          'song': songs[currentIndex].toJson(),
          'queue': songs.map((s) => s.toJson()).toList(),
        });

        // Update UI state - THIS WILL TRIGGER MINI PLAYER
        ref.read(musicPlayerProvider.notifier).playSong(localSong, allSongs);

        if (mounted) {
          _showSnackBar('Playing ${currentSong.title}', const Color(0xFF10B981));
        }

        if (kDebugMode) {
          print('🎵 Playing song: ${currentSong.title}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('❌ Error playing song: $e');
      }
      _showSnackBar('Error playing song: ${e.toString()}', Colors.red);
    }
  }

  // Helper method for snackbars
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_searchController.text.isNotEmpty) {
          _clearSearch();
          return false;
        }
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return false;
        }
        ref.read(currentTabIndexProvider.notifier).state = 0;
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            // Background Gradient
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
            
            // Content
            Column(
              children: [
                // Custom App Bar
                _buildCustomAppBar(),
                
                Expanded(child: _buildBody()),
              ],
            ),
          ],
        ),
        floatingActionButton: _isOnline ? null : _buildOfflineFab(),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0A0A).withOpacity(0.9),
            const Color(0xFF0A0A0A).withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back Button with Glassmorphism
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, 
                      color: Colors.white, size: 20),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _clearSearch();
                    } else {
                      ref.read(currentTabIndexProvider.notifier).state = 0;
                    }
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artists',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline 
                          ? '${_mainArtistList.length} artists available'
                          : 'Offline - Limited data',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Connectivity Indicator
              _buildConnectivityIndicator(),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Search Bar
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildConnectivityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isOnline 
            ? const Color(0xFF10B981).withOpacity(0.15)
            : const Color(0xFFF59E0B).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineFab() {
    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: const Color(0xFF8B5CF6),
      foregroundColor: Colors.white,
      elevation: 8,
      highlightElevation: 12,
      child: const Icon(Icons.refresh_rounded, size: 24),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search artists...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5), 
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded, 
            color: Colors.white.withOpacity(0.7), 
            size: 22
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded, 
                    color: Colors.white.withOpacity(0.7), 
                    size: 20
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (value) {
          if (value.isEmpty) {
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
          } else if (value.length >= 2) {
            _searchArtists(value);
          } else {
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    final bool hasSearchText = _searchController.text.isNotEmpty;
    final bool shouldShowSearchResults = _isSearching && hasSearchText;
    final List<Artist> displayList = shouldShowSearchResults ? _searchResults : _mainArtistList;

    if (_isLoading) return _buildShimmerLoader();
    if (_error.isNotEmpty) return _buildErrorWidget();

    if (displayList.isEmpty) {
      return _buildEmptyWidget(
        isSearching: shouldShowSearchResults,
        searchQuery: _searchController.text,
      );
    }

    return RefreshIndicator(
      backgroundColor: const Color(0xFF6366F1),
      color: Colors.white,
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (!_isOnline) _buildOfflineBanner(),
          _buildArtistsGrid(displayList),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildOfflineBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B).withOpacity(0.15),
              const Color(0xFFD97706).withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.3),
                    const Color(0xFFD97706).withOpacity(0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded, 
                color: Color(0xFFF59E0B), 
                size: 20
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Limited artist data available',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B).withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF6366F1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, 
                    color: Colors.white, size: 20),
                onPressed: _refreshData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[800]!,
                    Colors.grey[900]!,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withOpacity(0.3),
                    const Color(0xFFDC2626).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded, 
                color: Color(0xFFEF4444), 
                size: 50
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to Load Artists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error.length > 100 ? '${_error.substring(0, 100)}...' : _error,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loadArtists,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget({bool isSearching = false, String searchQuery = ''}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    const Color(0xFF8B5CF6).withOpacity(0.3),
                  ],
                ),
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.people_alt_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No Artists Found' : 'No Artists Yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'No results for "$searchQuery"\nTry different search terms'
                  : _isOnline
                      ? 'Your favorite artists will appear here\nStart exploring and adding music!'
                      : 'Connect to internet for complete artist data',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isSearching)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _clearSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Clear Search'),
                ),
              ),
            if (!isSearching && !_isOnline)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _refreshData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Check Connection'),
                ),
              ),
            if (!isSearching && _isOnline)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loadArtists,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Refresh Artists'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverGrid _buildArtistsGrid(List<Artist> displayList) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildArtistCard(displayList[index]),
        childCount: displayList.length,
      ),
    );
  }

  Widget _buildArtistCard(Artist artist) {
    final hasSpotifyData = artist.imageUrl.isNotEmpty && artist.followers != 'Local Artist';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          // Main Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!,
                  Colors.black,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showArtistDetails(artist),
                splashColor: const Color(0xFF6366F1).withOpacity(0.3),
                highlightColor: const Color(0xFF6366F1).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Artist Image
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: artist.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: artist.imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => _buildPlaceholderImage(),
                                    errorWidget: (context, url, error) => _buildPlaceholderImage(),
                                  )
                                : _buildPlaceholderImage(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Artist Name
                      Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Artist Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Followers
                          Row(
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                color: Colors.white.withOpacity(0.6),
                                size: 12,
                              ),
                              const SizedBox(width: 4, height: 2,),
                              Expanded(
                                child: Text(
                                  artist.followers,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Local Songs Count
                          if (artist.localSongsCount > 0)
                            Row(
                              children: [
                                Icon(
                                  Icons.library_music_rounded,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${artist.localSongsCount} songs',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          
                          // Popularity
                          if (artist.popularity > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.yellow[400],
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${artist.popularity}% popular',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Online Indicator
          if (hasSpotifyData && !_isOnline)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.4),
            const Color(0xFF8B5CF6).withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  void _showArtistDetails(Artist artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => ArtistDetailsSheet(artist: artist),
    );
  }
}

// ✅ FIXED: ArtistDetailsSheet with Play/Pause buttons and overflow fix
// ✅ FIXED: ArtistDetailsSheet with functional play/pause buttons
class ArtistDetailsSheet extends ConsumerStatefulWidget {
  final Artist artist;

  const ArtistDetailsSheet({super.key, required this.artist});

  @override
  ConsumerState<ArtistDetailsSheet> createState() => _ArtistDetailsSheetState();
}

class _ArtistDetailsSheetState extends ConsumerState<ArtistDetailsSheet> {
  // Audio Handler Methods
  BackgroundAudioHandler? get _audioHandler {
    try {
      final handler = main_app.globalAudioHandler;
      if (handler is BackgroundAudioHandler) {
        return handler;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Audio handler not available: $e');
      }
      return null;
    }
  }

  Future<bool> _isAudioServiceRunning() async {
    try {
      return AudioService.running;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _startAudioService() async {
    try {
      if (await _isAudioServiceRunning()) {
        return true;
      }

      await AudioService.start(
        backgroundTaskEntrypoint: _audioHandlerTaskEntrypoint,
        androidNotificationChannelName: 'Music Player',
        androidNotificationColor: 0xFF2196f3,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidEnableQueue: true,
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting audio service: $e');
      }
      return false;
    }
  }

  static void _audioHandlerTaskEntrypoint() async {
    AudioServiceBackground.run(() => BackgroundAudioHandler() as dynamic);
  }

  song_model.Song _convertLocalSongToSong(LocalSong localSong) {
    return song_model.Song(
      id: localSong.id,
      uri: localSong.uri.isNotEmpty ? localSong.uri : "file://${localSong.path}",
      title: localSong.title,
      artist: localSong.artist,
      album: localSong.album,
      duration: localSong.duration,
      mediaStoreId: int.tryParse(localSong.id) ?? localSong.id.hashCode.abs(),
      albumArt: null,
      genre: null,
      trackNumber: null,
      year: null,
      composer: null,
      playCount: 0,
      lastPlayed: DateTime.now(),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );
  }

  List<song_model.Song> _convertLocalSongsToSongs(List<LocalSong> localSongs) {
    return localSongs.map(_convertLocalSongToSong).toList();
  }

  // ✅ FIXED: Play/Pause functionality with state management
  Future<void> _togglePlayPause() async {
    try {
      final audioHandler = _audioHandler;
      if (audioHandler == null) return;

      final playbackState = audioHandler.playbackState;
      if (playbackState.value.playing) {
        await audioHandler.pause();
      } else {
        await audioHandler.play();
      }
      // Force UI update
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FIXED: Play all songs with proper state management
  Future<void> _playAllLocalSongs() async {
    try {
      if (widget.artist.localSongs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No songs available to play'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final serviceStarted = await _startAudioService();
      if (!serviceStarted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start audio service'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final audioHandler = _audioHandler;
      if (audioHandler == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio service not ready'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await audioHandler.waitForInitialization();
      final songs = _convertLocalSongsToSongs(widget.artist.localSongs);

      await audioHandler.customAction('setSongWithQueue', {
        'song': songs.first.toJson(),
        'queue': songs.map((s) => s.toJson()).toList(),
      });

      ref.read(musicPlayerProvider.notifier).playPlaylist(widget.artist.localSongs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing ${songs.length} songs by ${widget.artist.name}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      
      // Force UI update
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing songs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FIXED: Play single song with play/pause support
  Future<void> _playLocalSong(LocalSong song) async {
    try {
      final audioHandler = _audioHandler;
      if (audioHandler == null) return;

      final playbackState = audioHandler.playbackState;
      final currentMediaItem = audioHandler.mediaItem.value;
      
      // Check if this song is currently playing
      final isCurrentSong = currentMediaItem?.id == song.id;
      
      if (isCurrentSong && playbackState.value.playing) {
        // If current song is playing, pause it
        await audioHandler.pause();
      } else if (isCurrentSong && !playbackState.value.playing) {
        // If current song is paused, resume it
        await audioHandler.play();
      } else {
        // Play new song
        final serviceStarted = await _startAudioService();
        if (!serviceStarted) return;

        await audioHandler.waitForInitialization();
        final allSongs = _convertLocalSongsToSongs(widget.artist.localSongs);
        final currentSong = _convertLocalSongToSong(song);
        final currentIndex = allSongs.indexWhere((s) => s.id == currentSong.id);

        if (currentIndex != -1) {
          await audioHandler.customAction('setSongWithQueue', {
            'song': allSongs[currentIndex].toJson(),
            'queue': allSongs.map((s) => s.toJson()).toList(),
          });

          ref.read(musicPlayerProvider.notifier).playSong(song, widget.artist.localSongs);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playing ${song.title}'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        }
      }
      
      // Force UI update
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FIXED: Get current play state for a song
  bool _isSongPlaying(LocalSong song) {
    final audioHandler = _audioHandler;
    if (audioHandler == null) return false;
    
    final currentMediaItem = audioHandler.mediaItem.value;
    final playbackState = audioHandler.playbackState;
    
    return currentMediaItem?.id == song.id && playbackState.value.playing;
  }

  // ✅ FIXED: Check if any song from this artist is playing
  bool _isAnySongPlaying() {
    final audioHandler = _audioHandler;
    if (audioHandler == null) return false;
    
    final currentMediaItem = audioHandler.mediaItem.value;
    final playbackState = audioHandler.playbackState;
    
    if (!playbackState.value.playing) return false;
    
    // Check if current playing song belongs to this artist
    return widget.artist.localSongs.any((song) => song.id == currentMediaItem?.id);
  }

  // ✅ FIXED: Listen to audio state changes
  @override
  void initState() {
    super.initState();
    // Set up listener for audio state changes
    final audioHandler = _audioHandler;
    if (audioHandler != null) {
      audioHandler.playbackState.listen((state) {
        if (mounted) {
          setState(() {});
        }
      });
      
      audioHandler.mediaItem.listen((mediaItem) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = _audioHandler;
    final isAnySongPlaying = _isAnySongPlaying();
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            _buildArtistHeader(),
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    if (widget.artist.localSongs.isNotEmpty) _buildActionButtons(isAnySongPlaying),
                    if (widget.artist.localSongs.isNotEmpty) const SizedBox(height: 24),
                    if (widget.artist.localSongs.isNotEmpty) _buildLocalSongsSection(audioHandler),
                    const SizedBox(height: 24),
                    _buildArtistInfo(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artist Image
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: widget.artist.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.artist.imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _buildPlaceholderHeaderImage(),
                    )
                  : _buildPlaceholderHeaderImage(),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artist Name
                Text(
                  widget.artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Stats
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (widget.artist.followers != 'Local Artist')
                      _buildStatItem(
                        Icons.people_rounded,
                        widget.artist.followers,
                        const Color(0xFF10B981),
                      ),
                    _buildStatItem(
                      Icons.library_music_rounded,
                      '${widget.artist.localSongsCount}',
                      const Color(0xFF6366F1),
                    ),
                    if (widget.artist.popularity > 0)
                      _buildStatItem(
                        Icons.star_rounded,
                        '${widget.artist.popularity}%',
                        Colors.yellow,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderHeaderImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.4),
            const Color(0xFF8B5CF6).withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  // ✅ FIXED: Action buttons with dynamic play/pause state
  Widget _buildActionButtons(bool isAnySongPlaying) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Play/Pause All Button
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: Icon(
                  isAnySongPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                  color: Colors.white, 
                  size: 22
                ),
                label: Text(
                  isAnySongPlaying ? 'Pause All' : 'Play All',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _playAllLocalSongs,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildIconButton(
                  Icons.favorite_border_rounded,
                  () => _addToFavorites(),
                ),
                _buildIconButton(
                  Icons.share_rounded,
                  () => _shareArtist(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
        ),
      ),
    );
  }

  // ✅ FIXED: Local songs section with dynamic play/pause buttons
  Widget _buildLocalSongsSection(BackgroundAudioHandler? audioHandler) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.library_music_rounded, 
                  color: Color(0xFF6366F1), 
                  size: 20
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Local Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.artist.localSongsCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocalSongsList(),
        ],
      ),
    );
  }

  // ✅ FIXED: Local songs list with dynamic play/pause buttons
  Widget _buildLocalSongsList() {
    final songs = widget.artist.localSongs.take(5).toList();
    final hasMoreSongs = widget.artist.localSongs.length > 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final isPlaying = _isSongPlaying(song);
              
              return FutureBuilder<Uint8List?>(
                future: LocalSongsService().getAlbumArt(song.id, song.title, song.artist),
                builder: (context, snapshot) {
                  final albumArt = snapshot.data;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: albumArt != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  albumArt,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded, 
                                color: Colors.white, 
                                size: 20
                              ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${song.album} • ${song.formattedDuration}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ✅ FIXED: Dynamic Play/Pause button
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, 
                          size: 18
                        ),
                      ),
                      onTap: () => _playLocalSong(song),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              );
            },
          ),
          if (hasMoreSongs)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '+ ${widget.artist.localSongs.length - 5} more songs',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtistInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Artist Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.artist.followers != 'Local Artist') ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified_rounded, 
                          color: Color(0xFF10B981), 
                          size: 16
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Verified Artist',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.artist.followers != 'Local Artist') 
                  _buildInfoRow('Followers', widget.artist.followers),
                if (widget.artist.popularity > 0) 
                  _buildInfoRow('Popularity', '${widget.artist.popularity}%'),
                if (widget.artist.genres.isNotEmpty) 
                  _buildInfoRow('Genres', widget.artist.genres.take(3).join(', ')),
                if (widget.artist.followers == 'Local Artist')
                  _buildInfoRow('Status', 'Local Artist - ${widget.artist.localSongsCount} songs on your device'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToFavorites() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${widget.artist.name} to favorites'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareArtist() {
    if (kDebugMode) {
      print('Sharing artist: ${widget.artist.name}');
    }
  }
}