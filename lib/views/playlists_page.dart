import 'dart:io';
import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import 'playlist_detail_page.dart';
import '../services/favorites_service.dart';
import '../services/playback_service.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.playlistService,
    required this.favoritesService,
    required this.playbackService,
  });
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  final PlaybackService playbackService;
  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late Future<List<PlaylistModel>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture = widget.playlistService.getPlaylists();
  }

  Future<void> _createNewPlaylist() async {
    final name = await _showNewPlaylistDialog(context);
    if (name != null) {
      await widget.playlistService.createPlaylist(name);
      setState(() {
        _playlistsFuture = widget.playlistService.getPlaylists();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: const Text('新建收藏夹'),
                onPressed: _createNewPlaylist,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PlaylistModel>>(
            future: _playlistsFuture,
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
              final playlists = snapshot.data ?? [];
              if (playlists.isEmpty) {
                return const Center(child: Text('暂无收藏夹'));
              }
              return ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: playlist.coverPath != null
                        ? Image.file(File(playlist.coverPath!),
                            width: 40, height: 40)
                        : const Icon(Icons.music_note, size: 40),
                    title: Text(playlist.name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailPage(
                            playlist: playlist,
                            playlistService: widget.playlistService,
                            favoritesService: widget.favoritesService,
                            playbackService: widget.playbackService,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
          maxLength: 40,
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
