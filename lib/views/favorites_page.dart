import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/favorites_service.dart';
import '../services/playback_service.dart';
import '../widgets/song_list_item.dart';
import 'base_music_page.dart';

class FavoritesPage extends SongListPageBase {
  const FavoritesPage({
    super.key,
    required super.favoritesService,
    required super.playbackService,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends SongListPageBaseState<FavoritesPage> {
  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return widget.favoritesService.getFavoriteSongs();
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final confirm = await showDeleteDialog(
      context,
      '移除喜欢的歌曲',
      '是否从"我喜欢"中移除此歌曲？',
    );
    if (confirm == true) {
      await widget.favoritesService.toggleFavorite(song.id!);
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
      await widget.favoritesService.toggleFavorites(selectedSongIds.toList());
      await loadSongs();
    }
    return confirm;
  }
}
