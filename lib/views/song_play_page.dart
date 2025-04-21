import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/lyrics_service.dart';
import '../services/playback_service.dart';
import '../utils/thumbnail_generator.dart';
import '../widgets/lyrics_display.dart';
import '../services/playlist_service.dart';
import '../services/favorites_service.dart';

class SongPlayPage extends StatefulWidget {
  final SongModel song;
  final PlaybackService playbackService;
  final FavoritesService favoritesService;
  final PlaylistService playlistService;
  const SongPlayPage({
    super.key,
    required this.song,
    required this.playbackService,
    required this.favoritesService,
    required this.playlistService,
  });

  @override
  State<SongPlayPage> createState() => _SongPlayPageState();
}

class _SongPlayPageState extends State<SongPlayPage> {
  late Future<String> _lyricsFuture;
  Color _backgroundColor = Colors.grey; // 默认底色，待后端提供封面颜色提取

  @override
  void initState() {
    super.initState();
    _lyricsFuture = LyricsService().getLrcForSong(widget.song);
    _backgroundColor = Colors.grey; // 默认底色
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor.withOpacity(0.1),
      body: Stack(
        children: [
          Row(
            children: [
              // 左侧：封面和播放控制
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCover(),
                      const SizedBox(height: 16),
                      _buildPlaybackControls(context, widget.playlistService,
                          widget.favoritesService),
                    ],
                  ),
                ),
              ),
              // 右侧：歌曲信息和歌词
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSongInfo(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LyricsDisplay(
                          lyricsFuture: _lyricsFuture,
                          onTapLyric: (time) => PlaybackService().seekTo(time),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 左上角收回按钮
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    return FutureBuilder<Image>(
      future: ThumbnailGenerator().getOriginCover(widget.song.path),
      builder: (context, snapshot) {
        return Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: snapshot.hasData
                ? DecorationImage(
                    image: snapshot.data!.image,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: snapshot.hasData
              ? null
              : const Icon(Icons.music_note, size: 100, color: Colors.white),
        );
      },
    );
  }

  Widget _buildSongInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.song.title ?? '未知曲名',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.song.artist ?? '未知歌手',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          widget.song.album ?? '未知专辑',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(BuildContext context,
      PlaylistService playlistService, FavoritesService favoritesService) {
    final playbackService = Provider.of<PlaybackService>(context);

    return StreamBuilder<PlaybackState>(
      stream: playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
        final currentSong = state?.currentSong;
        if (currentSong == null) return const SizedBox();

        return Column(
          children: [
            Slider(
              value: (state?.position.inSeconds ?? 0).toDouble(),
              max: (state?.duration.inSeconds ?? 1).toDouble(),
              onChanged: (value) {
                playbackService.seekTo(value.toInt());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 24),
                  onPressed: playbackService.previous,
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                  onPressed: isPlaying
                      ? playbackService.pause
                      : playbackService.resume,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 24),
                  onPressed: playbackService.next,
                ),
                IconButton(
                  icon: Icon(
                    widget.song.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.song.isFavorite ? Colors.red : null,
                    size: 24,
                  ),
                  onPressed: () => _toggleFavorite(favoritesService),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add, size: 24),
                  onPressed: () =>
                      _showAddToPlaylistDialog(context, playlistService),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _toggleFavorite(FavoritesService favoritesService) {
    favoritesService.toggleFavorite(widget.song.id!);
  }

  void _showAddToPlaylistDialog(
      BuildContext context, PlaylistService playlistService) async {
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
                if (name != null) {
                  final newPlaylist =
                      await playlistService.createPlaylist(name);
                  await playlistService.addSongToPlaylist(
                      newPlaylist.id!, widget.song.id!);
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
                  playlistService.addSongToPlaylist(
                      playlist.id!, widget.song.id!);
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
}
