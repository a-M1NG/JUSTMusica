import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/playlist_service.dart';

class PlaybackControlBar extends StatelessWidget {
  const PlaybackControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final playbackService = Provider.of<PlaybackService>(context);
    return StreamBuilder<PlaybackState>(
      stream: playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final song = state?.currentSong;
        if (song == null) return const SizedBox(height: 80);

        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              _buildSongInfo(song),
              Expanded(child: _buildProgressBar(state)),
              _buildControls(context, playbackService, song),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(SongModel song) {
    return GestureDetector(
      onTap: () {
        // 切换到歌曲播放页面
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => SongPlayPage(song: song)));
      },
      child: Row(
        children: [
          song.coverPath != null
              ? Image.file(File(song.coverPath!), width: 50, height: 50)
              : const Icon(Icons.music_note, size: 50),
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

  Widget _buildProgressBar(PlaybackState state) {
    return Slider(
      value: state.position.inSeconds.toDouble(),
      max: state.duration.inSeconds.toDouble(),
      onChanged: (value) {
        playbackService.seekTo(value.toInt());
      },
    );
  }

  Widget _buildControls(
      BuildContext context, PlaybackService playbackService, SongModel song) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: SvgPicture.asset('assets/icons/previous.svg', width: 24),
          onPressed: playbackService.previous,
        ),
        IconButton(
          icon: SvgPicture.asset(
            state.isPlaying
                ? 'assets/icons/pause.svg'
                : 'assets/icons/play.svg',
            width: 24,
          ),
          onPressed:
              state.isPlaying ? playbackService.pause : playbackService.resume,
        ),
        IconButton(
          icon: SvgPicture.asset('assets/icons/next.svg', width: 24),
          onPressed: playbackService.next,
        ),
        IconButton(
          icon: SvgPicture.asset(
            song.isFavorite
                ? 'assets/icons/favorite_filled.svg'
                : 'assets/icons/favorite.svg',
            width: 24,
          ),
          onPressed: () => playbackService.toggleFavorite(song.id),
        ),
        IconButton(
          icon: SvgPicture.asset('assets/icons/add_to_playlist.svg', width: 24),
          onPressed: () => _showAddToPlaylistDialog(context, song),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, SongModel song) async {
    final playlists = await PlaylistService().getPlaylists();
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
                      await PlaylistService().createPlaylist(name);
                  await PlaylistService()
                      .addSongToPlaylist(newPlaylist.id!, song.id!);
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
                  PlaylistService().addSongToPlaylist(playlist.id!, song.id!);
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
