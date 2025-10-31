// lib/widgets/mini_player.dart - COMPLETELY FIXED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i_music/providers/app_providers.dart';
import 'package:i_music/main.dart' as main_app;
import 'package:i_music/screens/player_screen.dart';
import 'package:i_music/widgets/album_art_widget.dart'; // ✅ CORRECT IMPORT

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3), // ✅ FIXED: withOpacity is fine for now
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
              // ✅ FIXED: Use AlbumArtWidget as a Widget, not a method
              Padding(
                padding: const EdgeInsets.all(10),
                child: AlbumArtWidget( // ✅ This is a Widget class, not a method
                  song: currentSong,
                  size: 50.0,
                  borderRadius: 8.0,
                  showShadow: true,
                ),
              ),

              // Song Info
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

              // Playback controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                    onPressed: main_app.globalAudioHandler.skipToPrevious,
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        main_app.globalAudioHandler.pause();
                        ref.read(isPlayingProvider.notifier).state = false;
                      } else {
                        main_app.globalAudioHandler.play();
                        ref.read(isPlayingProvider.notifier).state = true;
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
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
  }
}