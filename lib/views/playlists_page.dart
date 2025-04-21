import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import 'playlist_detail_page.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late Future<List<PlaylistModel>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture = PlaylistService().getPlaylists();
  }

  Future<void> _createNewPlaylist() async {
    final name = await _showNewPlaylistDialog(context);
    if (name != null) {
      await PlaylistService().createPlaylist(name);
      setState(() {
        _playlistsFuture = PlaylistService().getPlaylists();
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
                icon: SvgPicture.asset('assets/icons/add.svg',
                    width: 20, height: 20),
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
                          builder: (_) =>
                              PlaylistDetailPage(playlist: playlist),
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
