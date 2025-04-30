import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../services/playlist_service.dart';
import '../models/playlist_model.dart';
import '../views/playlist_detail_page.dart';
import '../services/favorites_service.dart';
import '../views/setting_page.dart';
import '../services/playback_service.dart';
import '../utils/tools.dart';

class NavigationBarWidget extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  final PlaybackService playbackService;
  final Function() onPlaylistsChanged;
  const NavigationBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.playlistService,
    required this.favoritesService,
    required this.playbackService,
    required this.onPlaylistsChanged,
  });

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  bool _playlistsExpanded = false;
  bool _isHovering = false;
  int lastIndex = 4;
  @override
  Widget build(BuildContext context) {
    // debugPrint("curr nav bar color: ${Theme.of(context).primaryColor}");
    return Container(
      width: 250,
      color: Theme.of(context).primaryColor.withOpacity(0.5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: SvgPicture.asset('assets/images/text_logo.svg',
                width: 80, height: 30, color: Colors.white),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(0, '所有歌曲', Icons.library_music),
                  _buildNavItem(1, '我喜欢', Icons.favorite),
                  _buildNavItem(2, '播放列表', Icons.queue_music),
                  _buildPlaylistsSection(),
                ],
              ),
            ),
          ),
          // const Spacer(),
          // _buildSettingsButton(context),
          _buildNavItem(lastIndex, '设置', Icons.settings),
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

  Widget _buildSettingsButton(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.settings, size: 24, color: Colors.grey),
      title: const Text('设置'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );
  }

  Widget _buildPlaylistsSection() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_special, size: 24),
        title: const Text('收藏夹'),
        initiallyExpanded: _playlistsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _playlistsExpanded = expanded;
          });
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              visible: _isHovering || _playlistsExpanded,
              child: IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: _createNewPlaylist,
              ),
            ),
            Icon(
              _playlistsExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
          ],
        ),
        children: [
          // 这里调用后端接口获取收藏夹列表
          FutureBuilder<List<PlaylistModel>>(
            future: widget.playlistService.getPlaylists(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final playlists = snapshot.data!;
              lastIndex = 4 + playlists.length;
              return Column(
                children: playlists.asMap().entries.map((entry) {
                  final i = entry.key;
                  final playlist = entry.value;
                  return GestureDetector(
                    onSecondaryTapDown: (details) => _showContextMenu(
                        context, details.globalPosition, playlist),
                    child: ListTile(
                      leading: playlist.coverPath != null
                          ? Image.file(File(playlist.coverPath!),
                              width: 40, height: 40)
                          : const Icon(Icons.music_note),
                      title: Text(playlist.name),
                      onTap: () {
                        // 跳转到具体收藏夹页面
                        widget.onItemTapped(4 + i);
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //       builder: (_) => PlaylistDetailPage(
                        //           playlist: playlist,
                        //           playlistService: widget.playlistService,
                        //           favoritesService: widget.favoritesService,
                        //           playbackService: widget.playbackService)),
                        // );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, Offset position, PlaylistModel playlist) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    const double menuHeightEstimate = 100.0; // 估算菜单高度，可以根据实际菜单项调整

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
            onTap: () => _onPlayplaylist(playlist), child: const Text('播放')),
        PopupMenuItem(
            onTap: () => _onDeleteplaylist(playlist), child: const Text('删除')),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _onPlayplaylist(PlaylistModel playlist) async {
    // 播放收藏夹
    var playlistSongs =
        await widget.playlistService.getPlaylistSongs(playlist.id!);
    if (playlistSongs.isEmpty) {
      CreateMessage('收藏夹为空，无法播放', context);
      return;
    }
    widget.playbackService.setPlaybackList(playlistSongs, playlistSongs.first);
    widget.playbackService.playSong(playlistSongs.first);
  }

  Future<void> _onDeleteplaylist(PlaylistModel playlist) async {
    // 删除收藏夹
    final confirm = await _showDeleteDialog(context);
    if (confirm == true) {
      await widget.playlistService.deletePlaylist(playlist.id!);
      setState(() {});
      widget.onPlaylistsChanged();
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: const Text('是否删除此收藏夹？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _createNewPlaylist() async {
    final name = await _showNewPlaylistDialog(context);
    if (name != null) {
      // 调用后端接口创建收藏夹
      await widget.playlistService.createPlaylist(name);
      setState(() {});
      widget.onPlaylistsChanged();
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
