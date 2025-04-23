import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../utils/thumbnail_generator.dart';
import '../services/playlist_service.dart';
import '../services/database_service.dart';

class SongListItem extends StatelessWidget {
  final SongModel song;
  final int index;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onAddToNext;
  final bool? isMultiSelectMode; // 新增：是否为多选模式
  final bool? isSelected; // 新增：当前项是否选中
  final VoidCallback? onSelect; // 新增：切换选择状态

  const SongListItem({
    super.key,
    required this.song,
    required this.index,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onAddToNext,
    this.isMultiSelectMode,
    this.isSelected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isMultiSelectMode ?? false ? onSelect : doNothing, // 多选模式下点击切换选中状态
      onDoubleTap: isMultiSelectMode ?? false ? null : onPlay, // 非多选模式下双击播放
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        mouseCursor: SystemMouseCursors.basic,
        hoverColor: Colors.grey.withOpacity(0.1),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: isMultiSelectMode ?? false ? onSelect : doNothing,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 封面
              isMultiSelectMode ?? false
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (value) => onSelect?.call(),
                    )
                  : FutureBuilder<ImageProvider>(
                      future:
                          ThumbnailGenerator().getThumbnailProvider(song.path),
                      builder: (context, snapshot) {
                        double h = 45.0;
                        if (snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(
                              image: snapshot.data!,
                              width: h,
                              height: h,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: h,
                            height: h,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.music_note,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(width: 16),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title ?? '未知曲名',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist ?? '未知歌手',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 专辑信息
              Expanded(
                child: Text(
                  song.album ?? '未知专辑',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 收藏按钮
              IconButton(
                icon: Icon(
                  song.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: song.isFavorite ? Colors.red : null,
                ),
                onPressed: onToggleFavorite,
              ),

              // 时长
              Text(_formatDuration(song.duration)),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    const double menuHeightEstimate = 200.0; // 估算菜单高度，可以根据实际菜单项调整

    // 计算菜单的顶部位置，使其出现在点击位置的上方
    double top = position.dy - menuHeightEstimate;
    double left = position.dx;

    // 确保菜单不会超出屏幕顶部
    if (top < 0) {
      top = position.dy; // 如果超出顶部，则显示在点击位置下方
    }

    // 确保菜单不会超出屏幕右侧
    final screenWidth = overlay.size.width;
    const double menuWidthEstimate = 150.0; // 估算菜单宽度，可以根据实际调整
    if (left + menuWidthEstimate > screenWidth) {
      left = screenWidth - menuWidthEstimate;
    }

    // 创建 RelativeRect，定义菜单位置
    final RelativeRect relativeRect = RelativeRect.fromLTRB(
      left,
      top,
      screenWidth - (left + menuWidthEstimate),
      overlay.size.height - top - menuHeightEstimate,
    );

    showMenu(
      context: context,
      position: relativeRect,
      items: [
        PopupMenuItem(
          onTap: onAddToNext,
          child: const Text('下一首播放'),
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
    var dbService = DatabaseService();
    var playlistService = PlaylistService(await dbService.database);
    final playlists = await playlistService.getPlaylists();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('添加到收藏夹'),
            TextButton(
              onPressed: () async {
                final name = await _showNewPlaylistDialog(context);
                if (name != null && name.isNotEmpty) {
                  final newPlaylist =
                      await playlistService.createPlaylist(name);
                  await playlistService.addSongToPlaylist(
                      newPlaylist.id!, song.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加 ${song.title} 到新收藏夹: $name')),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('新建收藏'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                title: Text(playlist.name),
                onTap: () {
                  playlistService.addSongToPlaylist(playlist.id!, song.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('已添加 ${song.title} 到收藏夹: ${playlist.name}')),
                  );
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _showNewPlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入收藏夹名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? duration) {
    if (duration == null) return '00:00';
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void doNothing() {}
}
