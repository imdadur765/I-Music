// lib/utils/cached_image_provider.dart - UPDATED VERSION
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CachedImageProvider extends ImageProvider<CachedImageProvider> {
  final Uint8List imageData;
  final String key;

  const CachedImageProvider(this.imageData, {required this.key});

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      CachedImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.key,
    );
  }

  Future<Codec> _loadAsync(
      CachedImageProvider key, ImageDecoderCallback decode) async {
    assert(key == this);
    return await decode(await ImmutableBuffer.fromUint8List(imageData));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedImageProvider &&
        other.key == key &&
        listEquals(other.imageData, imageData);
  }

  @override
  int get hashCode => Object.hash(key, imageData.length);
}