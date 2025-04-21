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

class PlaybackControlBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: playbackService.playbackStateStream,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              _buildSongInfo(context, song),
              Expanded(
                  child: _buildProgressBar(context, state!, playbackService)),
              _buildControls(context, playbackService, state, song),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(BuildContext context, SongModel song) {
    return GestureDetector(
      onTap: () {
        // 切换到歌曲播放页面
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SongPlayPage(
                      song: song,
                      playbackService: playbackService,
                      favoritesService: favoritesService,
                      playlistService: playlistService,
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
    );
  }

  Widget _buildProgressBar(BuildContext context, PlaybackState state,
      PlaybackService playbackService) {
    return Slider(
      value: state.position.inSeconds.toDouble(),
      max: state.duration.inSeconds.toDouble(),
      onChanged: (value) {
        playbackService.seekTo(value.toInt());
      },
    );
  }

  Widget _buildControls(BuildContext context, PlaybackService playbackService,
      PlaybackState state, SongModel song) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: playbackService.previous,
        ),
        IconButton(
          icon: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
          onPressed:
              state.isPlaying ? playbackService.pause : playbackService.resume,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: playbackService.next,
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

  void _toggleFavorite(BuildContext context, SongModel song) {
    song.isFavorite = !song.isFavorite;
    favoritesService.toggleFavorite(song.id!);
  }

  void _showAddToPlaylistDialog(BuildContext context, SongModel song) async {
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
                      newPlaylist.id!, song.id!);
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
                  playlistService.addSongToPlaylist(playlist.id!, song.id!);
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
