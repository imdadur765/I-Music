import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/artist_model.dart';
import '../services/combined_artist_service.dart';
import '../services/local_songs_service.dart';
import 'home_screen.dart';

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final CombinedArtistService _combinedService = CombinedArtistService();

  // Main Spotify list (never cleared or overwritten after init)
  List<Artist> _mainArtistList = [];
  // Search results shown while user is typing
  List<Artist> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadArtists();
    // Keep UI in sync with text field changes without refetching main list
    _searchController.addListener(_onSearchTextChanged);
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
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load artists: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchArtists(String query) async {
    // If query becomes empty, stop searching and keep main list intact
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _isLoading = false;
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
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final text = _searchController.text;
    if (text.isEmpty) {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      } else {
        // Update UI (clear icon visibility)
        setState(() {});
      }
      return;
    }

    if (text.length >= 2) {
      _searchArtists(text);
    } else {
      // For single character, don't perform search — show main list
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      } else {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () {
              ref.read(currentTabIndexProvider.notifier).state = 0;
            },
          ),
        ),
        title: _buildSearchField(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search artists...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.5), size: 20),
                  onPressed: () {
                    _searchController.clear();
                    // Don't refetch main list; simply clear search results and show main list
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        onChanged: (value) {
          if (value.length >= 2) {
            _searchArtists(value);
          } else if (value.isEmpty) {
            // Clear only the search results and show main list; do not refetch
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
    final displayList = _isSearching ? _searchResults : _mainArtistList;

    if (_isLoading) return _buildShimmerLoader();
    if (_error.isNotEmpty) return _buildErrorWidget();
    if (displayList.isEmpty) return _buildEmptyWidget();

    return _buildArtistsGrid(displayList);
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[800],
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
        padding: const EdgeInsets.all(24.0),
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
                    Colors.red.withOpacity(0.3),
                    Colors.red.withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 50),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Artists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadArtists,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
              ),
              child: Icon(Icons.people_alt_rounded, color: Colors.white.withOpacity(0.8), size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Artists Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'Your favorite artists will appear here'
                  : 'No results for "${_searchController.text}"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchController.text.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  // Cancel search without refetching main artists
                  _searchController.clear();
                  setState(() {
                    _isSearching = false;
                    _searchResults = [];
                  });
                  _searchFocusNode.unfocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Clear Search'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsGrid(List<Artist> displayList) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Header with modern design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_rounded, color: Color(0xFF6366F1), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Your Artists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayList.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Artists Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                return _buildArtistCard(displayList[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistCard(Artist artist) {
    return GestureDetector(
      onTap: () => _showArtistDetails(artist),
      child: Container(
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
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                ),
              ),
            ),

            Column(
              children: [
                // Image section
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: artist.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artist.imageUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[900]!,
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
                ),

                // Content section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Artist name
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

                        // Local songs count badge
                        if (artist.localSongsCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.library_music_rounded, color: Colors.white.withOpacity(0.9), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${artist.localSongsCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Footer info
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, color: Colors.white.withOpacity(0.6), size: 12),
                            const SizedBox(width: 6),
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
                            if (artist.popularity > 0) ...[
                              Icon(Icons.star_rounded, color: Colors.yellow[400], size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${artist.popularity}%',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Hover overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showArtistDetails(artist),
                  splashColor: const Color(0xFF6366F1).withOpacity(0.3),
                  highlightColor: const Color(0xFF6366F1).withOpacity(0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.3),
            const Color(0xFF8B5CF6).withOpacity(0.3),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Modern geometric pattern
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // Main artist icon
          const Center(
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
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

class ArtistDetailsSheet extends StatelessWidget {
  final Artist artist;

  const ArtistDetailsSheet({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header section (fixed height)
          _buildArtistHeader(),
          const SizedBox(height: 16),

          // Scrollable content section
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24), // Added bottom padding
              child: Column(
                children: [
                  if (artist.localSongs.isNotEmpty) _buildActionButtons(context),
                  if (artist.localSongs.isNotEmpty) const SizedBox(height: 24),
                  if (artist.localSongs.isNotEmpty) _buildLocalSongsSection(),
                  const SizedBox(height: 24),
                  _buildArtistInfo(),
                  const SizedBox(height: 16), // Extra space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artist avatar with modern design
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: artist.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: artist.imageUrl,
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
                Text(
                  artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Stats row - made more compact
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (artist.followers != 'Local Artist')
                      _buildStatItem(
                        Icons.people_rounded,
                        artist.followers,
                        Colors.blue,
                      ),
                    _buildStatItem(
                      Icons.library_music_rounded,
                      '${artist.localSongsCount}',
                      const Color(0xFF6366F1),
                    ),
                    if (artist.popularity > 0)
                      _buildStatItem(
                        Icons.star_rounded,
                        '${artist.popularity}%',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Play All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
              ),
              onPressed: () {
                _playAllLocalSongs();
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildIconButton(
                  Icons.favorite_border_rounded,
                  () => _addToFavorites(context),
                ),
                _buildIconButton(
                  Icons.share_rounded,
                  _shareArtist,
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }

  Widget _buildLocalSongsSection() {
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.library_music_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Local Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  artist.localSongs.length.toString(),
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocalSongsList(),
        ],
      ),
    );
  }

  Widget _buildLocalSongsList() {
    final songs = artist.localSongs.take(5).toList(); // Limit to 5 songs to prevent overflow
    final hasMoreSongs = artist.localSongs.length > 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
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
              return FutureBuilder<Uint8List?>(
                future: LocalSongsService().getAlbumArt(song.id, song.title, song.artist),
                builder: (context, snapshot) {
                  final albumArt = snapshot.data;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                        ),
                        child: albumArt != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  albumArt,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${song.album} • ${song.formattedDuration}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                      ),
                      onTap: () {
                        _playLocalSong(song);
                      },
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
              padding: const EdgeInsets.all(12.0),
              child: Text(
                '+ ${artist.localSongs.length - 5} more songs',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (artist.followers != 'Local Artist') ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.green, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verified Artist',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (artist.followers != 'Local Artist') _buildInfoRow('Followers', artist.followers),
                if (artist.popularity > 0) _buildInfoRow('Popularity', '${artist.popularity}%'),
                if (artist.genres.isNotEmpty) _buildInfoRow('Genres', artist.genres.take(3).join(', ')),
                if (artist.followers == 'Local Artist')
                  _buildInfoRow('Status', 'Local Artist - ${artist.localSongsCount} songs on your device'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playAllLocalSongs() {
    if (kDebugMode) {
      print('Playing all ${artist.localSongs.length} local songs by ${artist.name}');
    }
  }

  void _playLocalSong(LocalSong song) {
    if (kDebugMode) {
      print('Playing local song: ${song.title}');
    }
  }

  void _addToFavorites(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${artist.name} to favorites'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareArtist() {
    if (kDebugMode) {
      print('Sharing artist: ${artist.name}');
    }
  }
}
