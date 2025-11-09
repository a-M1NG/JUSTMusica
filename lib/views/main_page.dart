import 'package:flutter/material.dart';
import 'package:just_musica/services/playback_service.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/playback_control_bar.dart';
import 'all_songs_page.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'playback_list_page.dart';
import '../services/database_service.dart';
import '../services/favorites_service.dart';
import '../services/playlist_service.dart';
import '../services/service_locator.dart';
import 'setting_page.dart';
import 'playlist_detail_page.dart';
import '../models/playlist_model.dart';

typedef VoidCallbackAsync = Future<void> Function();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  late List<PlaylistModel> _playlists = [];

  List<Widget> get _pages {
    List<Widget> res = [
      const AllSongsPage(),
      const FavoritesPage(),
      const PlaybackListPage(),
      const PlaylistsPage(),
    ];
    for (var playlist in _playlists) {
      res.add(PlaylistDetailPage(playlist: playlist));
    }
    res.add(const SettingsPage());
    return res;
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlistService = serviceLocator<PlaylistService>();
    _playlists = await playlistService.getPlaylists();
    if (mounted) {
      setState(() {}); // 触发 _pages 重建
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                NavigationBarWidget(
                  selectedIndex: _selectedIndex,
                  onItemTapped: _onNavItemTapped,
                  onPlaylistsChanged: _loadPlaylists,
                ),
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: Theme.of(context).canvasColor,
            child: PlaybackControlBar(
              onPlaylistsChanged: _loadPlaylists,
            ),
          ),
        ],
      ),
    );
  }
}
