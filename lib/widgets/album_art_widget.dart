// lib/widgets/album_art_widget.dart - COMPLETE FIXED VERSION
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/album_art_service.dart';
import '../utils/cached_image_provider.dart';
import '../models/song_model.dart';

final albumArtCacheProvider = Provider<AlbumArtCache>((ref) => AlbumArtCache());

class AlbumArtCache {
  final Map<String, Uint8List> _cache = {};
  
  Uint8List? get(String key) => _cache[key];
  
  void put(String key, Uint8List imageData) {
    if (_cache.length > 100) {
      // Limit cache size
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = imageData;
  }
  
  void clear() => _cache.clear();
  
  bool contains(String key) => _cache.containsKey(key);
}

class AlbumArtWidget extends ConsumerStatefulWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final BoxFit fit;
  final bool showPlaceholder;
  final bool showShadow;

  const AlbumArtWidget({
    Key? key,
    required this.song,
    this.size = 60.0,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    this.showPlaceholder = true,
    this.showShadow = true,
  }) : super(key: key);

  @override
  ConsumerState<AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends ConsumerState<AlbumArtWidget> {
  late Future<Uint8List?> _albumArtFuture;
  String? _currentCacheKey;

  @override
  void initState() {
    super.initState();
    _loadAlbumArt();
  }

  @override
  void didUpdateWidget(AlbumArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id || 
        oldWidget.song.albumArt != widget.song.albumArt) {
      _loadAlbumArt();
    }
  }

  void _loadAlbumArt() {
    final cache = ref.read(albumArtCacheProvider);
    _currentCacheKey = '${widget.song.id}_${widget.song.album}_${widget.song.artist}';
    
    // Check cache first
    final cachedImage = cache.get(_currentCacheKey!);
    if (cachedImage != null) {
      _albumArtFuture = Future.value(cachedImage);
    } else {
      // ✅ FIXED: Use correct parameters for AlbumArtService.getAlbumArt
      _albumArtFuture = AlbumArtService.getAlbumArt(
         songId: widget.song.mediaStoreId, // ✅ Directly use mediaStoreId (it's already int)
        songTitle: widget.song.title,
        artist: widget.song.artist,
      ).then((imageData) {
        if (imageData != null && _currentCacheKey != null) {
        cache.put(_currentCacheKey!, imageData);
       }
       return imageData;
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _albumArtFuture,
      builder: (context, snapshot) {
        final hasData = snapshot.hasData && snapshot.data != null;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
        if (hasData) {
          return _buildAlbumArtImage(snapshot.data!);
        }
        
        if (isLoading) {
          return _buildLoadingPlaceholder();
        }
        
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildAlbumArtImage(Uint8List imageData) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: widget.showShadow ? [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 6.0,
            offset: Offset(0, 3),
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image(
          image: CachedImageProvider(
            imageData,
            key: '${widget.song.id}_image', // ✅ FIXED: Use String instead of ValueKey
          ),
          fit: widget.fit,
          width: widget.size,
          height: widget.size,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: Colors.grey.shade300,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (!widget.showPlaceholder) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple,
            Colors.blue,
          ],
        ),
        boxShadow: widget.showShadow ? [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 6.0,
            offset: Offset(0, 3),
          ),
        ] : null,
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.white,
        size: widget.size * 0.35,
      ),
    );
  }
}

// Special widget for now playing screen with larger size
class NowPlayingAlbumArt extends StatelessWidget {
  final Song song;
  final double size;

  const NowPlayingAlbumArt({
    Key? key,
    required this.song,
    this.size = 200.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlbumArtWidget(
      song: song,
      size: size,
      borderRadius: 12.0,
      showShadow: true,
    );
  }
}

// Widget for notification/lock screen small album art
class NotificationAlbumArt extends StatelessWidget {
  final Song song;
  final double size;

  const NotificationAlbumArt({
    Key? key,
    required this.song,
    this.size = 64.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlbumArtWidget(
      song: song,
      size: size,
      borderRadius: 4.0,
      showShadow: false,
    );
  }
}