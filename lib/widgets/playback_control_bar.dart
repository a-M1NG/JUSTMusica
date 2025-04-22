import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/playlist_service.dart';
import '../services/favorites_service.dart';
import 'package:marquee/marquee.dart';
import '../utils/thumbnail_generator.dart';
import '../views/song_play_page.dart';
import '../utils/tools.dart';

class PlaybackControlBar extends StatefulWidget {
  const PlaybackControlBar({
    super.key,
    required this.playlistService,
    required this.favoritesService,
    required this.playbackService,
  });
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  final PlaybackService playbackService;

  @override
  State<PlaybackControlBar> createState() => _PlaybackControlBarState();
}

class _PlaybackControlBarState extends State<PlaybackControlBar> {
  // 用于存储拖动中的滑块位置
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final song = state?.currentSong;
        if (song == null) {
          return Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note,
                      color: Theme.of(context).disabledColor),
                  const SizedBox(width: 8),
                  Text('未播放歌曲',
                      style: TextStyle(color: Theme.of(context).disabledColor)),
                ],
              ),
            ),
          );
        }

        return Container(
          height: 80,
          // padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              _buildSongInfo(context, song),
              Expanded(child: _buildProgressBar(context, state!)),
              _buildControls(context, state, song),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(BuildContext context, SongModel song) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: Colors.grey.withOpacity(0.1),
        splashColor: Theme.of(context).primaryColor.withOpacity(0.2),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SongPlayPage(
                        song: song,
                        playbackService: widget.playbackService,
                        favoritesService: widget.favoritesService,
                        playlistService: widget.playlistService,
                      )));
        },
        child: Row(
          children: [
            FutureBuilder<ImageProvider>(
              future: ThumbnailGenerator().getThumbnailProvider(song.path),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image(
                    image: snapshot.data!,
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.music_note, size: 40),
                  );
                }
                return const Icon(Icons.music_note, size: 40);
              },
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 200,
              child: Marquee(
                text: '${song.title ?? '未知曲名'} - ${song.artist ?? '未知歌手'}',
                style: const TextStyle(fontSize: 16),
                scrollAxis: Axis.horizontal,
                blankSpace: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, PlaybackState state) {
    // 显示当前播放位置和总时长
    final position = formatDuration(_dragValue != null
        ? Duration(seconds: _dragValue!.round())
        : state.position);
    final duration = formatDuration(state.duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: _dragValue ?? state.position.inSeconds.toDouble(),
          max: state.duration.inSeconds.toDouble(),
          min: 0,
          onChanged: (value) {
            // 当用户拖动滑块时，更新UI显示但不立即seek
            setState(() {
              _dragValue = value;
            });
          },
          onChangeEnd: (value) {
            // 先执行seek操作，不要马上重置_dragValue
            // 等实际播放位置更新后，_dragValue会自然变成null
            widget.playbackService.seekTo(value.toInt()).then((_) {
              // 仅当当前拖动值仍然是这个值时才重置
              // 这样可以防止多次快速拖动时的闪烁
              if (_dragValue == value) {
                setState(() {
                  _dragValue = null;
                });
              }
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(position, style: const TextStyle(fontSize: 12)),
              Text(duration, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(
      BuildContext context, PlaybackState state, SongModel song) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: widget.playbackService.previous,
        ),
        IconButton(
          icon: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
          onPressed: state.isPlaying
              ? widget.playbackService.pause
              : widget.playbackService.resume,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: widget.playbackService.next,
        ),
        IconButton(
          icon: Icon(
            song.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: song.isFavorite ? Colors.red : null,
          ),
          onPressed: () => _toggleFavorite(context, song),
        ),
        IconButton(
          icon: const Icon(Icons.playlist_add),
          onPressed: () => _showAddToPlaylistDialog(context, song),
        ),
      ],
    );
  }

  // 格式化时间显示

  void _toggleFavorite(BuildContext context, SongModel song) {
    // 立即更新模型状态（乐观更新）
    setState(() {
      song.isFavorite = !song.isFavorite;
    });

    // 调用服务更新后端
    widget.favoritesService.toggleFavorite(song.id!);

    // 通知播放服务更新状态
    widget.playbackService.notifyListeners();
  }

  void _showAddToPlaylistDialog(BuildContext context, SongModel song) async {
    final playlists = await widget.playlistService.getPlaylists();
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
                if (name != null && name.trim().isNotEmpty) {
                  final newPlaylist =
                      await widget.playlistService.createPlaylist(name);
                  await widget.playlistService
                      .addSongToPlaylist(newPlaylist.id!, song.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加到新收藏夹: $name')),
                  );
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
                leading: const Icon(Icons.playlist_play),
                title: Text(playlist.name),
                onTap: () {
                  widget.playlistService
                      .addSongToPlaylist(playlist.id!, song.id!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加到收藏夹: ${playlist.name}')),
                  );
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
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
