import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/favorites_service.dart';
import '../widgets/song_list_item.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<SongModel>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = FavoritesService().getFavoriteSongs();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SongModel>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          return const Center(child: Text('暂无喜欢的歌曲'));
        }
        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            return SongListItem(
              song: favorites[index],
              index: index + 1,
              onPlay: () => _playSong(favorites[index]),
              onToggleFavorite: () => _toggleFavorite(favorites[index]),
              onDelete: () => _removeFavorite(favorites[index]),
              onAddToNext: () => _addToNext(favorites[index]),
            );
          },
        );
      },
    );
  }

  void _playSong(SongModel song) {
    // 调用后端接口播放歌曲并设置播放列表
    PlaybackService().setPlaybackList([song]);
    PlaybackService().playSong(song);
  }

  void _addToNext(SongModel song) {
    // 调用后端接口将歌曲加入下一首播放
    PlaybackService().playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    // 调用后端接口切换喜欢状态
    FavoritesService().toggleFavorite(song.id!);
    setState(() {
      _favoritesFuture = FavoritesService().getFavoriteSongs();
    });
  }

  void _removeFavorite(SongModel song) async {
    final confirm = await _showRemoveDialog(context);
    if (confirm == true) {
      // 调用后端接口移除喜欢
      await FavoritesService().toggleFavorite(song.id!);
      setState(() {
        _favoritesFuture = FavoritesService().getFavoriteSongs();
      });
    }
  }

  Future<bool?> _showRemoveDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除喜欢的歌曲'),
        content: const Text('是否从“我喜欢”中移除此歌曲？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}
