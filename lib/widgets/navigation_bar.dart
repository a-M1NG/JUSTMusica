import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../services/playlist_service.dart';
import '../services/service_locator.dart';
import '../models/playlist_model.dart';
import '../services/playback_service.dart';
import '../utils/tools.dart';
import 'package:just_musica/utils/thumbnail_generator.dart';

class NavigationBarWidget extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Function() onPlaylistsChanged;

  const NavigationBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onPlaylistsChanged,
  });

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  late final PlaylistService _playlistService;
  late final PlaybackService _playbackService;
  bool _playlistsExpanded = true;
  bool _isHovering = false;
  int _lastIndexForSettings = 4; // Initial base index for settings
  late Future<List<PlaylistModel>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    // 等待服务就绪后再访问
    await waitForServiceLocator();
    if (mounted) {
      _playlistService = serviceLocator<PlaylistService>();
      _playbackService = serviceLocator<PlaybackService>();
      _loadPlaylists();
    }
  }

  void _loadPlaylists() {
    _playlistsFuture = _playlistService.getPlaylists();
  }

  void _refreshPlaylists() {
    setState(() {
      _loadPlaylists(); // Get a new future to refresh the list
    });
    widget.onPlaylistsChanged(); // Notify parent about the change
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      width: 250,
      color: isDarkMode
          ? Colors.grey[900]!.withAlpha(150)
          : theme.primaryColor.withAlpha(150),
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
          // _buildNavItem(_lastIndexForSettings, '文件夹', Icons.folder),
          // _buildNavItem(_lastIndexForSettings + 1, '设置', Icons.settings),
          _buildNavItem(_lastIndexForSettings, '设置', Icons.settings),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData iconData) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(iconData, size: 24),
      title: Text(title),
      selected: widget.selectedIndex == index,
      onTap: () => widget.onItemTapped(index),
      hoverColor:
          isDarkMode ? Colors.white.withAlpha(77) : Colors.grey.withAlpha(51),
      selectedTileColor:
          isDarkMode ? Colors.white.withAlpha(77) : Colors.grey.withAlpha(51),
    );
  }

  Widget _buildPlaylistsSection() {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _isHovering = true;
        _refreshPlaylists();
      }),
      onExit: (_) => setState(() {
        _isHovering = false;
        _refreshPlaylists();
      }),
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
          FutureBuilder<List<PlaylistModel>>(
            future: _playlistsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(
                      child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                  )),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('加载错误: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _lastIndexForSettings = 4; // Base index if no playlists
                    });
                  }
                });
                return const ListTile(
                    title: Center(
                        child: Text("暂无收藏夹",
                            style: TextStyle(fontStyle: FontStyle.italic))));
              }
              final playlists = snapshot.data!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _lastIndexForSettings = 4 + playlists.length;
                  });
                }
              });
              return Column(
                children: playlists.asMap().entries.map((entry) {
                  final i = entry.key;
                  final playlist = entry.value;
                  return PlaylistItemWidget(
                    // Use a unique key for each playlist item to preserve state
                    key: ValueKey(playlist.id ??
                        playlist
                            .name), // Ensure playlist.id is available and unique
                    playlist: playlist,
                    onTap: () {
                      widget.onItemTapped(4 + i); // Index for playlist item
                    },
                    onSecondaryTapDown: (details) => _showContextMenu(
                        context, details.globalPosition, playlist),
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
    const double menuHeightEstimate = 100.0;
    double top = position.dy - menuHeightEstimate;
    double left = position.dx;

    if (top < 0) top = position.dy;

    final screenWidth = overlay.size.width;
    const double menuWidthEstimate = 150.0;
    if (left + menuWidthEstimate > screenWidth) {
      left = screenWidth - menuWidthEstimate;
    }
    if (left < 0) left = 0; // Ensure not off-screen to the left

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          left,
          top,
          overlay.size.width - left - menuWidthEstimate,
          overlay.size.height - top), // Adjusted RelativeRect
      items: [
        PopupMenuItem(
            onTap: () => _onPlayPlaylist(playlist), child: const Text('播放')),
        PopupMenuItem(
            onTap: () => _onDeletePlaylist(playlist), child: const Text('删除')),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _onPlayPlaylist(PlaylistModel playlist) async {
    if (playlist.id == null) {
      if (mounted) CreateMessage('收藏夹 ID 无效', context);
      return;
    }
    var playlistSongs = await _playlistService.getPlaylistSongs(playlist.id!);
    if (playlistSongs.isEmpty) {
      if (mounted) CreateMessage('收藏夹为空，无法播放', context);
      return;
    }
    _playbackService.setPlaybackList(playlistSongs, playlistSongs.first);
    _playbackService.playSong(playlistSongs.first);
  }

  Future<void> _onDeletePlaylist(PlaylistModel playlist) async {
    if (playlist.id == null) {
      if (mounted) CreateMessage('收藏夹 ID 无效，无法删除', context);
      return;
    }
    final confirm = await _showDeleteDialog(context, playlist.name);
    if (confirm == true) {
      await _playlistService.deletePlaylist(playlist.id!);
      _refreshPlaylists();
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String playlistName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text('是否删除收藏夹：$playlistName？'),
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
    final name = await showNewPlaylistDialog(context);
    if (name != null && name.isNotEmpty) {
      await _playlistService.createPlaylist(name);
      _refreshPlaylists();
    }
  }
}

// New StatefulWidget for individual playlist items
class PlaylistItemWidget extends StatefulWidget {
  final PlaylistModel playlist;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onSecondaryTapDown;

  const PlaylistItemWidget({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  State<PlaylistItemWidget> createState() => _PlaylistItemWidgetState();
}

class _PlaylistItemWidgetState extends State<PlaylistItemWidget> {
  Future<ImageProvider>? _imageProviderFuture;
  late final PlaylistService _playlistService;

  @override
  void initState() {
    super.initState();
    _loadImageProvider();
    _initializePlaylistService();
  }
  
  Future<void> _initializePlaylistService() async {
    await waitForServiceLocator();
    if (mounted) {
      _playlistService = serviceLocator<PlaylistService>();
    }
  }

  void _loadImageProvider() {
    // Only attempt to load if songs list is not null, not empty, and path is valid
    if (widget.playlist.songs != null &&
        widget.playlist.songs!.isNotEmpty &&
        widget.playlist.songs!.first.path.isNotEmpty) {
      // Check for non-empty path
      _imageProviderFuture = ThumbnailGenerator()
          .getThumbnailProvider(widget.playlist.songs!.first.path);
    } else {
      _imageProviderFuture =
          null; // Explicitly set to null if no valid image source
    }
  }

  // 构建圆角矩形图片 (成功加载时)
  Widget _buildPlaylistImage(ImageProvider imageProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0), // 您期望的圆角
      child: Image(
        image: imageProvider,
        // ListTile的leading区域通常较小，您示例的72x72可能过大。
        // CircleAvatar(radius: 20) 是 40x40，这里也用40x40作为示例。
        // 您可以根据实际效果调整。
        width: 40,
        height: 40,
        fit: BoxFit.cover, // 图片裁剪方式
        errorBuilder: (context, error, stackTrace) {
          // 图片渲染错误时的占位符
          debugPrint(
              "Error rendering image for '${widget.playlist.name}' in Image widget: $error");
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300], // 错误时的背景色
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(Icons.broken_image_outlined,
                size: 20, color: Colors.black54), // 错误图标
          );
        },
      ),
    );
  }

  // 构建加载中或无图片时的占位符 (圆角矩形)
  Widget _buildPlaceholderOrLoadingImage({bool isLoading = false}) {
    return Container(
      width: 40, // 与图片大小一致
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200], // 占位符背景色
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                // 加载指示器
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            : const Icon(Icons.music_note,
                size: 20, color: Colors.black54), // 默认音乐图标
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: ListTile(
        leading: (_imageProviderFuture != null)
            ? FutureBuilder<ImageProvider>(
                future: _imageProviderFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData && snapshot.data != null) {
                      // Future完成且有数据，显示图片
                      return _buildPlaylistImage(snapshot.data!);
                    } else {
                      // Future完成但无数据或出错 (例如getThumbnailProvider内部抛出异常)
                      debugPrint(
                          "FutureBuilder completed with error or no data for '${widget.playlist.name}': ${snapshot.error}");
                      return _buildPlaceholderOrLoadingImage(
                          isLoading: false); // 显示默认占位符
                    }
                  } else {
                    // Future还在加载中
                    return _buildPlaceholderOrLoadingImage(
                        isLoading: true); // 显示加载占位符
                  }
                },
              )
            : _buildPlaceholderOrLoadingImage(
                isLoading: false), // _imageProviderFuture为null时的默认占位符
        title: Text(widget.playlist.name, overflow: TextOverflow.ellipsis),
        onTap: () async {
          // 确保 widget.playlist.id 不为 null
          if (widget.playlist.id != null) {
            try {
              // 使用传递进来的 playlistService 获取歌曲列表
              final songs =
                  await _playlistService.getPlaylistSongs(widget.playlist.id!);
              if (mounted && songs.isNotEmpty && songs.first.path.isNotEmpty) {
                // 更新 _imageProviderFuture 并触发UI刷新
                setState(() {
                  _imageProviderFuture = ThumbnailGenerator()
                      .getThumbnailProvider(songs.first.path);
                });
              }
            } catch (e) {
              debugPrint(
                  "Error in onTap while refreshing playlist image for '${widget.playlist.name}': $e");
              // 即使图片刷新失败，也继续执行导航
            }
          }
          // 执行父组件传递过来的原始 onTap 回调（通常是导航）
          widget.onTap();
        },
      ),
    );
  }
}
