import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart'; // Import home screen for the provider

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // ✅ SIMPLE SOLUTION: Switch back to Songs tab (index 0)
            ref.read(currentTabIndexProvider.notifier).state = 0;
          },
        ),
        title: const Text(
          'Albums',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Albums Screen - Coming Soon',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}