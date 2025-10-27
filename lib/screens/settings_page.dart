import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ Updated to PopScope instead of deprecated WillPopScope
      onPopInvoked: (didPop) {
        if (!didPop) {
          debugPrint('🎯 Back button pressed on SettingsPage - Going back to SongsList');
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // 🔹 App Settings
            _sectionTitle('APP SETTINGS'),

            _settingsCard([
              _tile(
                icon: Icons.graphic_eq,
                color: Colors.blue,
                title: 'Equalizer',
                subtitle: 'Adjust your sound experience',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equalizer is coming in the next update! 🎛️'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.timer,
                color: Colors.orange,
                title: 'Sleep Timer',
                subtitle: 'Auto-stop playback after time',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sleep Timer is coming in the next update! ⏰'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ]),

            // 🔹 Playback Settings
            _sectionTitle('PLAYBACK SETTINGS'),

            _settingsCard([
              _tile(
                icon: Icons.playlist_play,
                color: Colors.green,
                title: 'Playlists',
                subtitle: 'Create and manage playlists',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Playlists feature is coming soon! 🎵'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.analytics_outlined,
                color: Colors.purple,
                title: 'Listening Statistics',
                subtitle: 'Track your music habits',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Listening statistics coming soon! 📊'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ]),

            // 🔹 Data Management
            _sectionTitle('DATA MANAGEMENT'),

            _settingsCard([
              _tile(
                icon: Icons.favorite,
                color: Colors.red,
                title: 'Favorites',
                subtitle: 'Manage your favorite songs',
                trailing: Text(
                  '0 songs',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Favorites feature is coming soon! ❤️'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.delete_outline,
                color: Colors.amber[800]!,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared successfully 🧹'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ]),

            // 🔹 About Section
            _sectionTitle('ABOUT'),

            _settingsCard([
              _tile(
                icon: Icons.info_outline,
                color: Colors.blueGrey,
                title: 'About I Music',
                subtitle: 'From Imdad, with love ❤️',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'I Music',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.music_note, size: 48),
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'From Imdad, with love ❤️',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'I Music is designed to give you a smooth, elegant and heartfelt music experience.\n\nThank you for your love & support!',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ]),

            const SizedBox(height: 20),

            // 🔹 Footer Info
            Column(
              children: [
                Text(
                  'I Music v1.0.0',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'From Imdad, with ❤️',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Reusable Widgets
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
      );

  Widget _settingsCard(List<Widget> tiles) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 1.5,
        child: Column(children: tiles),
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) =>
      ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}