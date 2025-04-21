import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/playlist_service.dart';

class NavigationBarWidget extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const NavigationBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
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
          _buildNavItem(0, '所有歌曲', 'assets/icons/songs.svg'),
          _buildNavItem(1, '我喜欢', 'assets/icons/favorite.svg'),
          _buildPlaylistsSection(),
          _buildNavItem(3, '播放列表', 'assets/icons/playlist.svg'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, String iconPath) {
    return ListTile(
      leading: SvgPicture.asset(iconPath, width: 24, height: 24),
      title: Text(title),
      selected: widget.selectedIndex == index,
      onTap: () => widget.onItemTapped(index),
    );
  }

  Widget _buildPlaylistsSection() {
    return ExpansionTile(
      leading:
          SvgPicture.asset('assets/icons/playlists.svg', width: 24, height: 24),
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
              icon: SvgPicture.asset('assets/icons/add.svg',
                  width: 20, height: 20),
              onPressed: _createNewPlaylist,
            ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        // 这里调用后端接口获取收藏夹列表
        FutureBuilder<List<PlaylistModel>>(
          future: PlaylistService().getPlaylists(),
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
                                builder: (_) =>
                                    PlaylistDetailPage(playlist: playlist)),
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
      await PlaylistService().createPlaylist(name);
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
