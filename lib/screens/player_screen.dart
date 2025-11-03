// lib/screens/player_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/models/song_model.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/widgets/album_art_widget.dart';
import 'package:audio_service/audio_service.dart';

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
  late final StreamSubscription<MediaItem?> _mediaItemSub;

  @override
  void initState() {
    super.initState();

    // Safe defaults
    _currentDuration = Duration.zero;
    _totalDuration = Duration.zero;

    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );

    // Start only if playing (we will check playing state shortly)
    // But don't call ref.read(...) synchronously here for play state;
    // we'll control animation in build when we know playing state.

    // Listen for mediaItem changes so UI rebuilds when notification controls change track
    _mediaItemSub =
        main_app.globalAudioHandler.mediaItem.listen((mediaItem) {
      if (mounted) {
        // Update durations quickly if mediaItem provides duration
        if (mediaItem?.duration != null) {
          _totalDuration = mediaItem!.duration!;
        }
        // Trigger a rebuild so UI picks up new title/art/artist etc.
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _mediaItemSub.cancel();
    super.dispose();
  }

  void _updateProgress() {
    final playbackState = main_app.globalAudioHandler.playbackState.value;
    final position = playbackState.position;
    final mediaItem = main_app.globalAudioHandler.mediaItem.value;

    if (mediaItem != null) {
      final totalMs = mediaItem.duration?.inMilliseconds ?? 0;
      if (totalMs > 0) {
        setState(() {
          _currentDuration = position;
          _totalDuration = mediaItem.duration ?? Duration.zero;
          if (!_isDragging) {
            _currentPosition =
                totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;
          }
        });
      }
    } else {
      // fallback: keep progress zero
      setState(() {
        _currentDuration = position;
        // _totalDuration unchanged
      });
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
      final newPosition =
          Duration(milliseconds: (clampedValue * totalMs).round());
      main_app.globalAudioHandler.seek(newPosition);
    }

    // small debounce to release dragging
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localOffset = renderBox.globalToLocal(details.globalPosition);
    final newPosition = (localOffset.dx / constraints.maxWidth).clamp(0.0, 1.0);

    setState(() {
      _currentPosition = newPosition;
    });
  }

  void _handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final double tapPosition = details.localPosition.dx;
    final double totalWidth = constraints.maxWidth;
    final double newPosition = (tapPosition / totalWidth).clamp(0.0, 1.0);
    _seekToPosition(newPosition);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Helper: convert MediaItem -> Song (fallback) or extract Song from extras
  Song _songFromMediaItem(MediaItem mediaItem) {
    // If you stored the original Song object in extras as 'song_object', use it
    final extras = mediaItem.extras;
    if (extras != null && extras['song_object'] is Song) {
      return extras['song_object'] as Song;
    }

    // Otherwise create a lightweight Song fallback from MediaItem fields
    return Song(
      id: mediaItem.id,
      uri: (mediaItem.extras?['uri'] ?? mediaItem.id).toString(),
      title: mediaItem.title,
      artist: mediaItem.artist ?? 'Unknown Artist',
      album: mediaItem.album,
      duration: mediaItem.duration?.inMilliseconds ?? 0,
      albumArt: mediaItem.artUri?.toString(),
      mediaStoreId:
          int.tryParse(mediaItem.extras?['mediaStoreId']?.toString() ?? '') ??
              0,
      genre: mediaItem.genre,
      trackNumber:
          (mediaItem.extras?['trackNumber'] is int) ? mediaItem.extras!['trackNumber'] as int : 0,
      year:
          (mediaItem.extras?['year'] is int) ? mediaItem.extras!['year'] as int : 0,
      composer: mediaItem.extras?['composer']?.toString(),
      playCount: 0,
      lastPlayed: DateTime.now(),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use stream builders so UI reacts instantly to audio_service streams
    return StreamBuilder<MediaItem?>(
      stream: main_app.globalAudioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        return StreamBuilder<PlaybackState>(
          stream: main_app.globalAudioHandler.playbackState,
          builder: (context, playbackSnapshot) {
            // Keep progress updated each frame after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateProgress();
            });

            final mediaItem = mediaSnapshot.data;
            final playbackState = playbackSnapshot.data;
            final audioHandlerPlaying = playbackState?.playing ?? false;

            // Derive displaySong: prefer mediaItem extras song_object, else fallback to provider or mediaItem mapping
            Song? displaySong;
            if (mediaItem != null) {
              displaySong = _songFromMediaItem(mediaItem);
            } else {
              // fallback to Riverpod currentSongProvider (it's a StreamProvider)
              final maybeSong = ref.watch(currentSongProvider);
              displaySong = maybeSong.maybeWhen(data: (s) => s, orElse: () => null);
            }

            final bool displayPlaying = audioHandlerPlaying;

            // Rotation control: start/stop based on playing state
            if (displayPlaying) {
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }
            } else {
              if (_rotationController.isAnimating) {
                _rotationController.stop();
              }
            }

            if (displaySong == null) {
              // If nothing to show, keep a minimal loader
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                ),
              );
            }

            return WillPopScope(
              onWillPop: () async {
                // default behavior: pop
                return true;
              },
              child: Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: Column(
                    children: [
                      // App Bar with back button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 6.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_downward,
                                  color: Colors.white, size: 28),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Now Playing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white, size: 28),
                              onPressed: () {
                                if (kDebugMode) debugPrint('More options');
                              },
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 5),

                              // Animated Rounded Album Art with Rotation
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle:
                                          _rotationController.value * 2 * 3.14159,
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        height:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.deepPurple.withOpacity(
                                                      0.3),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: NowPlayingAlbumArt(
                                            song: displaySong!,
                                            size: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 1.5),

                              // Song Info that updates automatically
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                child: Column(
                                  children: [
                                    Text(
                                      displaySong.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        height: 1,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      displaySong.artist,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    if (displaySong.album != null &&
                                        displaySong.album!.isNotEmpty)
                                      Text(
                                        displaySong.album!,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 5),

                              // Progress and Seek Bar with better drag
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(_currentDuration),
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(_totalDuration),
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 5),

                                    // Seek Bar with drag & tap
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (details) =>
                                              _handleTapDown(details, constraints),
                                          onPanStart: (details) {
                                            setState(() {
                                              _isDragging = true;
                                            });
                                          },
                                          onPanUpdate: (details) =>
                                              _handleDragUpdate(details, constraints),
                                          onPanEnd: (details) {
                                            _seekToPosition(_currentPosition);
                                          },
                                          onPanCancel: () {
                                            _seekToPosition(_currentPosition);
                                          },
                                          child: Container(
                                            height: 40,
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 12),
                                            child: Stack(
                                              alignment: Alignment.centerLeft,
                                              children: [
                                                // Background track
                                                Container(
                                                  height: 4,
                                                  width: constraints.maxWidth,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade800,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                ),
                                                // Progress track
                                                AnimatedContainer(
                                                  duration: _isDragging
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 200),
                                                  height: 4,
                                                  width: constraints.maxWidth *
                                                      (_currentPosition.isNaN
                                                          ? 0.0
                                                          : _currentPosition),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.deepPurple.shade400,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                ),
                                                // Thumb
                                                AnimatedPositioned(
                                                  duration: _isDragging
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 200),
                                                  left:
                                                      (constraints.maxWidth * (_currentPosition.isNaN ? 0.0 : _currentPosition)) -
                                                          8,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          blurRadius: 4,
                                                          offset:
                                                              const Offset(0, 2),
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
                              ),

                              const SizedBox(height: 20),

                              // Playback Controls
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.shuffle,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('Shuffle pressed');
                                        }
                                      },
                                    ),

                                    IconButton(
                                      icon: const Icon(Icons.skip_previous_rounded,
                                          color: Colors.white, size: 30),
                                      iconSize: 30,
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('⏮️ Skip to previous from player screen');
                                        }
                                        main_app.globalAudioHandler.skipToPrevious();
                                      },
                                    ),

                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.deepPurple.shade400,
                                            Colors.purple.shade600,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.deepPurple.withOpacity(0.5),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          displayPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        iconSize: 30,
                                        onPressed: () {
                                          if (displayPlaying) {
                                            main_app.globalAudioHandler.pause();
                                          } else {
                                            main_app.globalAudioHandler.play();
                                          }
                                        },
                                      ),
                                    ),

                                    IconButton(
                                      icon: const Icon(Icons.skip_next_rounded,
                                          color: Colors.white, size: 30),
                                      iconSize: 30,
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('⏭️ Skip to next from player screen');
                                        }
                                        main_app.globalAudioHandler.skipToNext();
                                      },
                                    ),

                                    IconButton(
                                      icon: Icon(
                                        Icons.repeat,
                                        color: Colors.grey.shade400,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('Repeat pressed');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

                              // Additional Controls
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.favorite_border,
                                        color: Colors.white70,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('Favorite pressed');
                                        }
                                      },
                                    ),

                                    IconButton(
                                      icon: const Icon(
                                        Icons.volume_up,
                                        color: Colors.white70,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        if (kDebugMode) {
                                          debugPrint('Volume control pressed');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
