// ignore_for_file: deprecated_member_use

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
    // Define colors for each tab
    final List<Color> activeColors = [
      Colors.lightBlueAccent, // Songs - Light Blue
      Colors.redAccent,       // Artists - Red
      Colors.greenAccent,     // Albums - Green
      Colors.orangeAccent,    // Favorites - Orange
    ];

    final List<Color> inactiveColors = [
      Colors.lightBlueAccent.withOpacity(0.5),
      Colors.redAccent.withOpacity(0.5),
      Colors.greenAccent.withOpacity(0.5),
      Colors.orangeAccent.withOpacity(0.5),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarButton(
              icon: Icons.music_note,
              label: 'Songs',
              isActive: currentIndex == 0,
              activeColor: activeColors[0],
              inactiveColor: inactiveColors[0],
              onTap: () => _onTabTapped(0, ref),
            ),
            _NavBarButton(
              icon: Icons.person,
              label: 'Artists',
              isActive: currentIndex == 1,
              activeColor: activeColors[1],
              inactiveColor: inactiveColors[1],
              onTap: () => _onTabTapped(1, ref),
            ),
            _NavBarButton(
              icon: Icons.album,
              label: 'Albums',
              isActive: currentIndex == 2,
              activeColor: activeColors[2],
              inactiveColor: inactiveColors[2],
              onTap: () => _onTabTapped(2, ref),
            ),
            _NavBarButton(
              icon: Icons.favorite,
              label: 'Favorites',
              isActive: currentIndex == 3,
              activeColor: activeColors[3],
              inactiveColor: inactiveColors[3],
              onTap: () => _onTabTapped(3, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _onTabTapped(int index, WidgetRef ref) {
    if (currentIndex != index) {
      ref.read(currentTabIndexProvider.notifier).state = index;
    }
  }
}

// Custom navigation bar button widget
class _NavBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavBarButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20), // More rounded corners
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20), // More rounded corners
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), // Reduced padding
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // More rounded corners
                color: isActive 
                    ? activeColor.withOpacity(0.15)
                    : Colors.transparent,
                border: isActive
                    ? Border.all(
                        color: activeColor.withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6), // Reduced padding
                    decoration: BoxDecoration(
                      color: isActive 
                          ? activeColor.withOpacity(0.2)
                          : inactiveColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? activeColor : inactiveColor,
                        width: isActive ? 2 : 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 18, // Smaller icon size
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 3), // Reduced spacing
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? activeColor : inactiveColor,
                      fontSize: 10, // Smaller font size
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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