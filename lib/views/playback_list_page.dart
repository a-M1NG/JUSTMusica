import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../widgets/song_list_item.dart';
import '../services/favorites_service.dart';

class PlaybackListPage extends StatefulWidget {
  const PlaybackListPage({super.key, required this.favoritesService});
  final FavoritesService favoritesService;
  @override
  State<PlaybackListPage> createState() => _PlaybackListPageState();
}

class _PlaybackListPageState extends State<PlaybackListPage> {
  late Future<List<SongModel>> _playbackListFuture;

  @override
  void initState() {
    super.initState();
    _playbackListFuture = PlaybackService().getPlaybackList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SongModel>>(
      future: _playbackListFuture,
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
        final songs = snapshot.data ?? [];
        if (songs.isEmpty) {
          return const Center(child: Text('播放列表为空'));
        }
        return ListView(
          children: songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            return KeyedSubtree(
              key: ValueKey(song.id),
              child: SongListItem(
                song: song,
                index: index + 1,
                onPlay: () => _playSong(song),
                onToggleFavorite: () => _toggleFavorite(song),
                onDelete: () => _removeFromPlaybackList(song),
                onAddToNext: () => _addToNext(song),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _playSong(SongModel song) {
    // 调用后端接口播放歌曲
    PlaybackService().playSong(song);
  }

  void _addToNext(SongModel song) {
    // 调用后端接口将歌曲加入下一首播放
    PlaybackService().playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    // 调用后端接口切换喜欢状态
    widget.favoritesService.toggleFavorite(song.id!);
    setState(() {
      _playbackListFuture = PlaybackService().getPlaybackList();
    });
  }

  void _removeFromPlaybackList(SongModel song) async {
    final confirm = await _showRemoveDialog(context);
    if (confirm == true) {
      // 调用后端接口移除歌曲
      await PlaybackService().setPlaybackList(
        (await _playbackListFuture).where((s) => s.id != song.id).toList(),
      );
      setState(() {
        _playbackListFuture = PlaybackService().getPlaybackList();
      });
    }
  }

  Future<bool?> _showRemoveDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除歌曲'),
        content: const Text('是否从播放列表中移除此歌曲？'),
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
