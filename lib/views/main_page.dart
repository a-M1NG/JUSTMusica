import 'package:flutter/material.dart';
import 'package:just_musica/services/playback_service.dart';
import 'package:just_musica/views/base_music_page.dart';
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
  late List<PlaylistModel> _playlists;
  DatabaseService? _dbService;
  FavoritesService? _favoritesService;
  PlaylistService? _playlistService;
  bool _isInitializing = true;

  List<Widget> get _pages {
    if (_favoritesService == null || _playlistService == null) {
      return [const Center(child: CircularProgressIndicator())];
    }
    final playbackService =
        Provider.of<PlaybackService>(context, listen: false);
    List<Widget> res = [
      AllSongsPage(
        favoritesService: _favoritesService!,
        databaseService: _dbService!,
        playbackService: playbackService,
      ),
      FavoritesPage(
        favoritesService: _favoritesService!,
        playbackService: playbackService,
      ),
      PlaybackListPage(
        favoritesService: _favoritesService!,
        playbackService: playbackService,
      ),
      PlaylistsPage(
        playlistService: _playlistService!,
        favoritesService: _favoritesService!,
        playbackService: playbackService,
      ),
    ];
    for (var playlist in _playlists) {
      res.add(PlaylistDetailPage(
          playlist: playlist,
          playlistService: _playlistService!,
          favoritesService: _favoritesService!,
          playbackService: playbackService));
    }
    res.add(SettingsPage());
    return res;
  }

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      debugPrint('Initializing services...');
      // Initialize database service
      _dbService = DatabaseService();
      final db = await _dbService!.database;

      // Initialize dependent services
      _favoritesService = FavoritesService(db);
      _playlistService = PlaylistService(db);

      await _updatePlaylists();

      setState(() {
        _isInitializing = false;
      });
      debugPrint('Services initialized successfully');
    } catch (e) {
      // Handle initialization error
      debugPrint('Service initialization failed: $e');
      // You might want to show an error screen here
    }
  }

  Future<void> _updatePlaylists() async {
    _playlists = await _playlistService!.getPlaylists();
    setState(() {}); // 触发 _pages 重建
  }

  @override
  void dispose() {
    _dbService?.close();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playbackService =
        Provider.of<PlaybackService>(context, listen: false);
    if (_isInitializing || _dbService == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: _dbService!),
        Provider<FavoritesService>.value(value: _favoritesService!),
        Provider<PlaylistService>.value(value: _playlistService!),
      ],
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  NavigationBarWidget(
                    selectedIndex: _selectedIndex,
                    onItemTapped: _onNavItemTapped,
                    playlistService: _playlistService!,
                    favoritesService: _favoritesService!,
                    playbackService: playbackService,
                    onPlaylistsChanged: _updatePlaylists,
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
                playlistService: _playlistService!,
                favoritesService: _favoritesService!,
                playbackService: playbackService,
                onPlaylistsChanged: _updatePlaylists,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
