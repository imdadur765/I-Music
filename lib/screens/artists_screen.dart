import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/artist_model.dart'; // ✅ SINGLE IMPORT
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

  List<Artist> _artists = []; // ✅ Simple List<Artist>
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
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
        _artists = artists;
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
    if (query.isEmpty) {
      await _loadArtists();
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final artists = await _combinedService.searchCombinedArtists(query);
      
      setState(() {
        _artists = artists;
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(currentTabIndexProvider.notifier).state = 0;
          },
        ),
        title: _buildSearchField(),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search artists...',
        hintStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  _loadArtists();
                },
              )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        if (value.length >= 2) {
          _searchArtists(value);
        } else if (value.isEmpty) {
          _loadArtists();
        }
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerLoader();
    }

    if (_error.isNotEmpty) {
      return _buildErrorWidget();
    }

    if (_artists.isEmpty) {
      return _buildEmptyWidget();
    }

    return _buildArtistsGrid();
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[800],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load artists',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadArtists,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No artists found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Artists will appear here soon'
                : 'No results for "${_searchController.text}"',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (_searchController.text.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _loadArtists();
              },
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }

  Widget _buildArtistsGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Text(
                  'Your Artists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _artists.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _artists.length,
              itemBuilder: (context, index) {
                return _buildArtistCard(_artists[index]);
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
          borderRadius: BorderRadius.circular(15),
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 30).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: artist.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: artist.imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  if (artist.localSongsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade800,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${artist.localSongsCount} Local Songs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  if (artist.localSongsCount > 0) const SizedBox(height: 6),
                  
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.grey, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          artist.followers,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (artist.popularity > 0) ...[
                        const Icon(Icons.star, color: Colors.yellow, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${artist.popularity}%',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
      color: Colors.grey[800],
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  void _showArtistDetails(Artist artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
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
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildArtistHeader(),
                  const SizedBox(height: 20),
                  if (artist.localSongs.isNotEmpty) _buildActionButtons(context),
                  if (artist.localSongs.isNotEmpty) const SizedBox(height: 20),
                  if (artist.localSongs.isNotEmpty) _buildLocalSongsSection(),
                  const SizedBox(height: 20),
                  _buildArtistInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
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
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                artist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              if (artist.followers != 'Local Artist')
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${artist.followers} followers',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              
              if (artist.followers != 'Local Artist') const SizedBox(height: 4),
              
              Row(
                children: [
                  const Icon(Icons.library_music, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${artist.localSongsCount} local songs',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              if (artist.popularity > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.yellow, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${artist.popularity}% popularity',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderHeaderImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[800],
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text(
              'Play Local Songs',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              _playAllLocalSongs();
            },
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.favorite_border, color: Colors.white),
          onPressed: () {
            _addToFavorites(context);
          },
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
            _shareArtist();
          },
        ),
      ],
    );
  }

  Widget _buildLocalSongsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.library_music, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Your Local Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                artist.localSongs.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        _buildLocalSongsList(),
      ],
    );
  }

  Widget _buildLocalSongsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: artist.localSongs.length,
        itemBuilder: (context, index) {
          final song = artist.localSongs[index];
          return FutureBuilder<Uint8List?>(
            future: LocalSongsService().getAlbumArt(song.id, song.title, song.artist),
            builder: (context, snapshot) {
              final albumArt = snapshot.data;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: albumArt != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            albumArt,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.music_note, color: Colors.white, size: 20),
                ),
                title: Text(
                  song.title,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${song.album} • ${song.formattedDuration}',
                  style: const TextStyle(color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.blue),
                  onPressed: () {
                    _playLocalSong(song);
                  },
                ),
                onTap: () {
                  _playLocalSong(song);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildArtistInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artist Info',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (artist.followers != 'Local Artist') ...[
                Text(
                  'Data provided by Spotify',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Followers: ${artist.followers}',
                  style: const TextStyle(color: Colors.white),
                ),
                if (artist.popularity > 0)
                  Text(
                    'Popularity: ${artist.popularity}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                if (artist.genres.isNotEmpty)
                  Text(
                    'Genres: ${artist.genres.join(', ')}',
                    style: const TextStyle(color: Colors.white),
                  ),
              ] else 
                Text(
                  'Local Artist - ${artist.localSongsCount} songs on your device',
                  style: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ],
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
      ),
    );
  }

  void _shareArtist() {
    if (kDebugMode) {
      print('Sharing artist: ${artist.name}');
    }
  }
}