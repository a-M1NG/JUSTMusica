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

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  DatabaseService? _dbService;
  FavoritesService? _favoritesService;
  PlaylistService? _playlistService;
  PlaybackService? _playbackService;
  bool _isInitializing = true;

  List<Widget> get _pages {
    if (_favoritesService == null || _playlistService == null) {
      return [const Center(child: CircularProgressIndicator())];
    }

    return [
      AllSongsPage(
        favoritesService: _favoritesService!,
        databaseService: _dbService!,
        playbackService: _playbackService!,
      ),
      FavoritesPage(
        favoritesService: _favoritesService!,
        playbackService: _playbackService!,
      ),
      PlaylistsPage(
        playlistService: _playlistService!,
        favoritesService: _favoritesService!,
        playbackService: _playbackService!,
      ),
      PlaybackListPage(
        favoritesService: _favoritesService!,
        playbackService: _playbackService!,
      ),
    ];
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
      _playbackService = PlaybackService();

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
        body: Row(
          children: [
            NavigationBarWidget(
              selectedIndex: _selectedIndex,
              onItemTapped: _onNavItemTapped,
              playlistService: _playlistService!,
              favoritesService: _favoritesService!,
              playbackService: _playbackService!,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _pages[_selectedIndex]),
                  PlaybackControlBar(
                    playlistService: _playlistService!,
                    favoritesService: _favoritesService!,
                    playbackService: _playbackService!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
