import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'songs_list_screen.dart';
import 'artists_screen.dart';
import 'albums_screen.dart';
import 'favorites_screen.dart';
import '../widgets/mini_player.dart';

// ✅ PERFORMANCE: Create a provider for current index
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);
    
    return WillPopScope(
      onWillPop: () async {
        // ✅ Agar home tab (0 - Songs) pe hain toh app minimize karo
        if (currentIndex == 0) {
          // App minimize karne ke liye true return karo
          return true;
        } else {
          // ✅ Agar other tabs (1,2,3) pe hain toh home tab pe switch karo
          ref.read(currentTabIndexProvider.notifier).state = 0;
          return false; // System back rok do
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        drawer: const _AppDrawer(),
        body: Stack(
          children: [
            // ✅ PERFORMANCE: Use PageView with PageStorage for state preservation
            _TabContent(index: currentIndex),
            
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(currentIndex: currentIndex),
      ),
    );
  }
}

// ✅ PERFORMANCE: Extract tab content to separate widget
class _TabContent extends StatelessWidget {
  final int index;

  const _TabContent({required this.index});

  @override
  Widget build(BuildContext context) {
    return PageStorage(
      bucket: PageStorageBucket(),
      child: IndexedStack(
        index: index,
        children: const [
          SongsListScreen(),
          ArtistsScreen(),
          AlbumsScreen(),
          FavoritesScreen(),
        ],
      ),
    );
  }
}

// ✅ PERFORMANCE: Extract bottom nav bar to separate widget
class _BottomNavBar extends ConsumerWidget {
  final int currentIndex;

  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        // ✅ Only update if index changed
        if (currentIndex != index) {
          ref.read(currentTabIndexProvider.notifier).state = index;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.black,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.music_note),
          label: 'Songs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Artists',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.album),
          label: 'Albums',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Favorites',
        ),
      ],
    );
  }
}

// ✅ PERFORMANCE: Extract drawer to separate widget
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey[900],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _DrawerHeader(),
          _DrawerItem(
            icon: Icons.account_circle,
            title: 'Account',
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.info,
            title: 'About',
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: Colors.grey),
          _DrawerItem(
            icon: Icons.exit_to_app,
            title: 'Logout',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ✅ PERFORMANCE: Extract drawer header
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
          ),
          SizedBox(height: 10),
          Text(
            'iMusic User',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Premium Member',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ✅ PERFORMANCE: Extract drawer item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}