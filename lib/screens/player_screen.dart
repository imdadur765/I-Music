// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/models/song_model.dart';

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

  void _seekToPosition(double value) {
    setState(() {
      _isDragging = true;
      _currentPosition = value;
    });
    
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs > 0) {
      final newPosition = Duration(milliseconds: (value * totalMs).round());
      main_app.globalAudioHandler.seek(newPosition);
    }
    
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _isDragging = false;
      });
    });
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

    // ✅ FIXED: Use PopScope instead of WillPopScope
    return PopScope(
      canPop: false, // ✅ Yeh important hai - manually handle karo back button
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
              // ✅ App Bar with back button - FIXED
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

              // ✅ Rest of your existing code remains SAME...
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 5),

                      // Album Art
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.width * 0.8,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          image: (displaySong.albumArt != null && 
                                  displaySong.albumArt!.isNotEmpty &&
                                  !displaySong.albumArt!.startsWith('content://'))
                              ? DecorationImage(
                                  image: NetworkImage(displaySong.albumArt!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: (displaySong.albumArt == null || 
                                  displaySong.albumArt!.isEmpty ||
                                  displaySong.albumArt!.startsWith('content://'))
                              ? Colors.deepPurple.shade400
                              : null,
                          gradient: (displaySong.albumArt == null || 
                                    displaySong.albumArt!.isEmpty ||
                                    displaySong.albumArt!.startsWith('content://'))
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.deepPurple.shade400,
                                    Colors.purple.shade600,
                                  ],
                                )
                              : null,
                        ),
                        child: (displaySong.albumArt == null || 
                                displaySong.albumArt!.isEmpty ||
                                displaySong.albumArt!.startsWith('content://'))
                            ? const Icon(Icons.music_note, color: Colors.white, size: 60)
                            : null,
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

                      // Progress and Seek Bar
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
                            
                            GestureDetector(
                              onTapDown: (details) {
                                final box = context.findRenderObject() as RenderBox?;
                                if (box != null) {
                                  final localOffset = box.globalToLocal(details.globalPosition);
                                  final newPosition = localOffset.dx / box.size.width;
                                  _seekToPosition(newPosition.clamp(1.0, 1.0));
                                }
                              },
                              onHorizontalDragStart: (details) {
                                setState(() {
                                  _isDragging = true;
                                });
                              },
                              onHorizontalDragUpdate: (details) {
                                final box = context.findRenderObject() as RenderBox?;
                                if (box != null) {
                                  final localOffset = box.globalToLocal(details.globalPosition);
                                  final newPosition = localOffset.dx / box.size.width;
                                  setState(() {
                                    _currentPosition = newPosition.clamp(1.0, 1.0);
                                  });
                                }
                              },
                              onHorizontalDragEnd: (details) {
                                _seekToPosition(_currentPosition);
                              },
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                                      height: 4,
                                      width: MediaQuery.of(context).size.width * _currentPosition,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade400,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    Positioned(
                                      left: MediaQuery.of(context).size.width * _currentPosition - 8,
                                      top: -4,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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