import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import '../models/song_model.dart';
import '../utils/thumbnail_generator.dart';
import '../services/playlist_service.dart';
import '../services/database_service.dart';
import 'package:shimmer/shimmer.dart';

class SongListItem extends StatefulWidget {
  final SongModel song;
  final int index;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onAddToNext;
  final bool? isMultiSelectMode;
  final bool? isSelected;
  final VoidCallback? onSelect;

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
  _SongListItemState createState() => _SongListItemState();
}

class _SongListItemState extends State<SongListItem> {
  bool _shouldLoadRealContent = false;
  bool _isVisible = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(widget.song.id),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0 && !_shouldLoadRealContent) {
          _isVisible = true;
          _timer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && _isVisible) {
              setState(() {
                _shouldLoadRealContent = true;
              });
            }
          });
        } else if (visibilityInfo.visibleFraction == 0) {
          _isVisible = false;
          _timer?.cancel();
          _timer = null;
        }
      },
      child: _shouldLoadRealContent
          ? GestureDetector(
              onTap: widget.isMultiSelectMode ?? false
                  ? widget.onSelect
                  : doNothing,
              onDoubleTap:
                  widget.isMultiSelectMode ?? false ? null : widget.onPlay,
              onSecondaryTapDown: (details) =>
                  _showContextMenu(context, details.globalPosition),
              child: InkWell(
                mouseCursor: SystemMouseCursors.basic,
                hoverColor: Colors.grey.withOpacity(0.1),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: widget.isMultiSelectMode ?? false
                    ? widget.onSelect
                    : doNothing,
                child: _buildRealContent(),
              ),
            )
          : _buildSkeleton(context),
    );
  }

  Widget _buildRealContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          widget.isMultiSelectMode ?? false
              ? Checkbox(
                  value: widget.isSelected,
                  onChanged: (value) => widget.onSelect?.call(),
                )
              : FutureBuilder<ImageProvider>(
                  future: ThumbnailGenerator()
                      .getThumbnailProvider(widget.song.path),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title ?? '未知曲名',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.song.artist ?? '未知歌手',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              widget.song.album ?? '未知专辑',
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              widget.song.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: widget.song.isFavorite ? Colors.red : null,
            ),
            onPressed: widget.onToggleFavorite,
          ),
          Text(_formatDuration(widget.song.duration)),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 封面骨架
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),

            // 统一信息条（曲名 + 艺术家）骨架
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 收藏按钮 + 时长 一体骨架
            Container(
              width: 70,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    const double menuHeightEstimate = 200.0;
    double top = position.dy - menuHeightEstimate;
    double left = position.dx;
    if (top < 0) {
      top = position.dy;
    }
    final screenWidth = overlay.size.width;
    const double menuWidthEstimate = 150.0;
    if (left + menuWidthEstimate > screenWidth) {
      left = screenWidth - menuWidthEstimate;
    }
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
          onTap: widget.onAddToNext,
          child: const Text('下一首播放'),
        ),
        PopupMenuItem(
          child: const Text('加入收藏夹'),
          onTap: () => _showAddToPlaylistDialog(context),
        ),
        PopupMenuItem(onTap: widget.onPlay, child: const Text('播放')),
        PopupMenuItem(onTap: widget.onDelete, child: const Text('删除')),
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
                      newPlaylist.id!, widget.song.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('已添加 ${widget.song.title} 到新收藏夹: $name')),
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
                  playlistService.addSongToPlaylist(
                      playlist.id!, widget.song.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '已添加 ${widget.song.title} 到收藏夹: ${playlist.name}'),
                    ),
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
