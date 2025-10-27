// lib/widgets/cached_artwork.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/artwork_manager.dart';

class CachedArtwork extends StatefulWidget {
  final String songId;
  final Uint8List? artworkData;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const CachedArtwork({
    Key? key,
    required this.songId,
    required this.artworkData,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  }) : super(key: key);

  @override
  State<CachedArtwork> createState() => _CachedArtworkState();
}

class _CachedArtworkState extends State<CachedArtwork> {
  late Uint8List? _cachedArtwork;

  @override
  void initState() {
    super.initState();
    _initializeArtwork();
  }

  void _initializeArtwork() {
    // Pehle cache check karo
    _cachedArtwork = ArtworkManager().getCachedArtwork(widget.songId);
    
    // Agar cache nahi hai aur artwork data available hai, toh cache karo
    if (_cachedArtwork == null && widget.artworkData != null) {
      _cachedArtwork = widget.artworkData;
      ArtworkManager().cacheArtwork(widget.songId, widget.artworkData!);
      
      // Background mein temp file banao system notification ke liye
      ArtworkManager().getArtworkUri(widget.songId, widget.artworkData);
    }
  }

  @override
  void didUpdateWidget(CachedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artworkData != oldWidget.artworkData || widget.songId != oldWidget.songId) {
      _initializeArtwork();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedArtwork == null || _cachedArtwork!.isEmpty) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    return Image.memory(
      _cachedArtwork!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.width != null ? (widget.width! * 2).toInt() : null,
      cacheHeight: widget.height != null ? (widget.height! * 2).toInt() : null,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: Icon(
        Icons.music_note,
        color: Colors.grey[600],
        size: widget.width != null ? widget.width! * 0.4 : 24,
      ),
    );
  }
}