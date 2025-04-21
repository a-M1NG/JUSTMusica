import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song_model.dart';
import '../utils/thumbnail_generator.dart';
import '../services/playlist_service.dart'; // 添加缺失的导入

class SongListItem extends StatelessWidget {
  final SongModel song;
  final int index;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onAddToNext; // 新增参数

  const SongListItem({
    super.key,
    required this.song,
    required this.index,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onAddToNext, // 新增参数
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(song.title ?? '未知曲名'),
      subtitle: Text(song.artist ?? '未知歌手'),
      trailing: SizedBox(
        width: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(child: Text(song.album ?? '未知专辑')),
            IconButton(
              icon: Icon(
                song.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: song.isFavorite ? Colors.red : null,
              ),
              onPressed: onToggleFavorite,
            ),
            Text(_formatDuration(song.duration)),
          ],
        ),
      ),
      leading: FutureBuilder<String>(
        future: ThumbnailGenerator().getThumbnail(song.path),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.file(File(snapshot.data!), width: 40, height: 40);
          }
          return const Icon(Icons.music_note, size: 40);
        },
      ),
      onTap: onPlay,
      onLongPress: () => _showContextMenu(context),
    );
  }

  void _showContextMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        PopupMenuItem(
          onTap: onAddToNext,
          child: const Text('下一首播放'), // 改为使用传入的回调方法
        ),
        PopupMenuItem(
          child: const Text('加入收藏夹'),
          onTap: () => _showAddToPlaylistDialog(context),
        ),
        PopupMenuItem(onTap: onPlay, child: const Text('播放')),
        PopupMenuItem(onTap: onDelete, child: const Text('删除')),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) async {
    // 实现添加到播放列表的对话框
    // 这里需要实现具体逻辑
  }

  String _formatDuration(int? duration) {
    if (duration == null) return '00:00';
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
