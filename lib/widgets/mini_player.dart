// lib/widgets/mini_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/screens/player_screen.dart';
import 'package:i_music/widgets/album_art_widget.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSongAsync = ref.watch(currentSongProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);

    return currentSongAsync.when(
      data: (currentSong) {
        if (currentSong == null) return const SizedBox.shrink();

        final isPlaying = isPlayingAsync.value ?? false;

        return Container(
          height: 70,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black87,
            border: Border(top: BorderSide(color: Colors.grey.shade800)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PlayerScreen()),
                );
              },
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: AlbumArtWidget(
                      song: currentSong,
                      size: 50.0,
                      borderRadius: 8.0,
                      showShadow: true,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSong.artist,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white, size: 28),
                        onPressed: main_app.globalAudioHandler.skipToPrevious,
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            main_app.globalAudioHandler.pause();
                          } else {
                            main_app.globalAudioHandler.play();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white, size: 28),
                        onPressed: main_app.globalAudioHandler.skipToNext,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}