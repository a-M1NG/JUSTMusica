import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/playback_control_bar.dart';
import 'all_songs_page.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'playback_list_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const AllSongsPage(),
    const FavoritesPage(),
    const PlaylistsPage(),
    const PlaybackListPage(),
  ];

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationBarWidget(
            selectedIndex: _selectedIndex,
            onItemTapped: _onNavItemTapped,
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _pages[_selectedIndex]),
                const PlaybackControlBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
