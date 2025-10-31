// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';
import 'package:i_music/widgets/album_art_widget.dart'; // ✅ ADDED

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _currentPosition = 0.0;
  bool _isDragging = false;
  late Duration _currentDuration;
  late Duration _totalDuration;

  @override
  void initState() {
    super.initState();
    _initializeProgress();
  }

  void _initializeProgress() {
    final currentSong = ref.read(currentSongProvider);
    _totalDuration = Duration(milliseconds: currentSong?.duration ?? 0);
    _currentDuration = Duration.zero;
    _currentPosition = 0.0;
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
            _currentPosition = position.inMilliseconds / totalMs;
          }
        });
      }
    }
  }

  // ✅ FIXED: Seek bar functionality
  void _seekToPosition(double value) {
    final clampedValue = value.clamp(0.0, 1.0); // ✅ Ensure value is between 0-1
    setState(() {
      _isDragging = true;
      _currentPosition = clampedValue;
    });
    
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs > 0) {
      final newPosition = Duration(milliseconds: (clampedValue * totalMs).round());
      main_app.globalAudioHandler.seek(newPosition);
    }
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }

  // ✅ ADDED: Tap to seek functionality
  void _handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final double tapPosition = details.localPosition.dx;
    final double totalWidth = constraints.maxWidth;
    final double newPosition = (tapPosition / totalWidth).clamp(0.0, 1.0);
    _seekToPosition(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProgress();
    });

    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    
    final mediaItem = main_app.globalAudioHandler.mediaItem.value;
    final playbackState = main_app.globalAudioHandler.playbackState.value;
    final audioHandlerPlaying = playbackState.playing;

    final Song? displaySong = currentSong ?? (mediaItem?.extras?['song_object'] as Song?);
    final bool displayPlaying = isPlaying || audioHandlerPlaying;

    if (displaySong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          debugPrint('🎯 Back button pressed on PlayerScreen - Going back to SongList');
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // ✅ App Bar with back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 28),
                      onPressed: () {
                        debugPrint('🎯 Down arrow pressed on PlayerScreen - Going back to SongList');
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
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                      onPressed: () {
                        if (kDebugMode) {
                          debugPrint('More options pressed');
                        }
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

                      // ✅ UPDATED: Album Art with AlbumArtWidget
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: NowPlayingAlbumArt(
                          song: displaySong,
                          size: MediaQuery.of(context).size.width * 0.8,
                        ),
                      ),

                      const SizedBox(height: 1.5),

                      // Song Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
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
                            if (displaySong.album != null && displaySong.album!.isNotEmpty)
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

                      // ✅ FIXED: Progress and Seek Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
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
                            
                            // ✅ FIXED: Seek Bar with proper gesture detection
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onTapDown: (details) => _handleTapDown(details, constraints),
                                  onHorizontalDragStart: (details) {
                                    setState(() {
                                      _isDragging = true;
                                    });
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    final localOffset = details.localPosition;
                                    final newPosition = (localOffset.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                    setState(() {
                                      _currentPosition = newPosition;
                                    });
                                  },
                                  onHorizontalDragEnd: (details) {
                                    _seekToPosition(_currentPosition);
                                  },
                                  onHorizontalDragCancel: () {
                                    _seekToPosition(_currentPosition);
                                  },
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // Background track
                                        Container(
                                          height: 4,
                                          width: constraints.maxWidth,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade800,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        // Progress track
                                        AnimatedContainer(
                                          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                                          height: 4,
                                          width: constraints.maxWidth * _currentPosition,
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.shade400,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        // Thumb
                                        AnimatedPositioned(
                                          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                                          left: (constraints.maxWidth * _currentPosition) - 8,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                    color: Colors.deepPurple.withOpacity(0.5),
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
                                  if (kDebugMode) {
                                    debugPrint('${displayPlaying ? '⏸️' : '▶️'} Play/Pause from player screen');
                                  }
                                  if (displayPlaying) {
                                    main_app.globalAudioHandler.pause();
                                    ref.read(isPlayingProvider.notifier).state = false;
                                  } else {
                                    main_app.globalAudioHandler.play();
                                    ref.read(isPlayingProvider.notifier).state = true;
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
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}