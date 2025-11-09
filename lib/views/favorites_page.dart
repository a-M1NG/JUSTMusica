import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/service_locator.dart';
import '../services/favorites_service.dart';
import 'base_music_page.dart';

class FavoritesPage extends SongListPageBase {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends SongListPageBaseState<FavoritesPage> {
  late final FavoritesService _favoritesService;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    await waitForServiceLocator();
    if (mounted) {
      _favoritesService = serviceLocator<FavoritesService>();
      // Reload songs after service is initialized
      loadSongs();
    }
  }

  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return _favoritesService.getFavoriteSongs();
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final confirm = await showDeleteDialog(
      context,
      '移除喜欢的歌曲',
      '是否从"我喜欢"中移除此歌曲？',
    );
    if (confirm == true) {
      await _favoritesService.toggleFavorite(song.id!);
      await loadSongs();
    }
  }

  @override
  String getPageTitle() => '我喜欢的音乐';

  @override
  List<Widget> getAppBarActions() => [];

  @override
  String getEmptyMessage() => '暂无喜欢的歌曲';

  @override
  Future<bool?> onDeleteSelected() async {
    final confirm = await showDeleteDialog(
      context,
      '移除喜欢的歌曲',
      '是否从"我喜欢"中移除这些歌曲？',
    );
    if (confirm == true) {
      await _favoritesService.toggleFavorites(selectedSongIds.toList());
      await loadSongs();
    }
    return confirm;
  }
}
