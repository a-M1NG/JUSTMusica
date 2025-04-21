import 'dart:io';
import 'package:flutter/material.dart';
import '../services/playlist_service.dart';
import '../models/playlist_model.dart';
import '../views/playlist_detail_page.dart';
import '../services/favorites_service.dart';

class NavigationBarWidget extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  const NavigationBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.playlistService,
    required this.favoritesService,
  });

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  bool _playlistsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          _buildNavItem(0, '所有歌曲', Icons.library_music),
          _buildNavItem(1, '我喜欢', Icons.favorite),
          _buildPlaylistsSection(),
          _buildNavItem(3, '播放列表', Icons.queue_music),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData iconData) {
    return ListTile(
      leading: Icon(iconData, size: 24),
      title: Text(title),
      selected: widget.selectedIndex == index,
      onTap: () => widget.onItemTapped(index),
    );
  }

  Widget _buildPlaylistsSection() {
    return ExpansionTile(
      leading: const Icon(Icons.folder_special, size: 24),
      title: const Text('收藏夹'),
      onExpansionChanged: (expanded) {
        setState(() {
          _playlistsExpanded = expanded;
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_playlistsExpanded)
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _createNewPlaylist,
            ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        // 这里调用后端接口获取收藏夹列表
        FutureBuilder<List<PlaylistModel>>(
          future: widget.playlistService.getPlaylists(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final playlists = snapshot.data!;
            return Column(
              children: playlists
                  .map((playlist) => ListTile(
                        leading: playlist.coverPath != null
                            ? Image.file(File(playlist.coverPath!),
                                width: 40, height: 40)
                            : const Icon(Icons.music_note),
                        title: Text(playlist.name),
                        onTap: () {
                          // 跳转到具体收藏夹页面
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlaylistDetailPage(
                                    playlist: playlist,
                                    playlistService: widget.playlistService,
                                    favoritesService: widget.favoritesService)),
                          );
                        },
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _createNewPlaylist() async {
    final name = await _showNewPlaylistDialog(context);
    if (name != null) {
      // 调用后端接口创建收藏夹
      await widget.playlistService.createPlaylist(name);
      setState(() {});
    }
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
