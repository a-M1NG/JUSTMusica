import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';
import '../widgets/song_list_item.dart';
import '../services/database_service.dart';
import '../services/playlist_service.dart';

abstract class SongListPageBase extends StatefulWidget {
  final PlaybackService playbackService;
  final FavoritesService favoritesService;

  const SongListPageBase({
    super.key,
    required this.playbackService,
    required this.favoritesService,
  });
}

abstract class SongListPageBaseState<T extends SongListPageBase>
    extends State<T> {
  late Future<List<SongModel>> songsFuture;
  List<SongModel> loadedSongs = [];
  Set<int> selectedSongIds = {};
  @override
  void initState() {
    super.initState();
    loadSongs();
  }

  final ScrollController _scrollController = ScrollController();
  // 抽象方法：加载歌曲列表
  Future<List<SongModel>> loadSongsImplementation();

  // 加载歌曲并缓存
  Future<void> loadSongs() async {
    songsFuture = loadSongsImplementation();
    songsFuture.then((songs) {
      setState(() {
        loadedSongs = songs;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 播放歌曲
  void playSong(SongModel song) {
    widget.playbackService.setPlaybackList(loadedSongs);
    widget.playbackService.playSong(song);
  }

  // 将歌曲加入下一首播放
  void addToNext(SongModel song) {
    widget.playbackService.playNext(song.id!);
  }

  // 切换收藏状态
  void toggleFavorite(SongModel song) {
    setState(() {
      song.isFavorite = !song.isFavorite;
    });
    widget.favoritesService.toggleFavorite(song.id!);
  }

  // 抽象方法：删除歌曲
  Future<void> deleteSong(SongModel song);

  // 显示删除确认对话框
  Future<bool?> showDeleteDialog(
      BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  bool _isMultiSelectMode = false;
  bool get isMultiSelectMode => _isMultiSelectMode;
  set isMultiSelectMode(bool value) {
    _isMultiSelectMode = value;
    if (!value) {
      setState(() {
        selectedSongIds.clear();
      });
    }
  }

  // 切换多选模式
  void OnMultiSelection(BuildContext context) {
    setState(() {
      isMultiSelectMode = !isMultiSelectMode;
      if (!isMultiSelectMode) {
        selectedSongIds.clear(); // 退出多选模式时清除选择
      }
    });
  }

  void toggleSelection(int songId) {
    setState(() {
      if (selectedSongIds.contains(songId)) {
        selectedSongIds.remove(songId);
      } else {
        selectedSongIds.add(songId);
      }
    });
  }

  Future<bool?> onDeleteSelected() async {}
  void _onDeleteSelected() async {
    if (selectedSongIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    var res = await onDeleteSelected();
    if (res == true) {
      isMultiSelectMode = false;
    }
  }

  Widget? getHeader() => null;
  Widget? getFooter() => null;
  void onAddToFavoritesSelected() {
    if (selectedSongIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择歌曲')),
      );
      return;
    }
    _showAddToPlaylistDialog(context);
  }

  void _showAddToPlaylistDialog(BuildContext context) async {
    var dbService = DatabaseService();
    var playlistService = PlaylistService(await dbService.database);
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
                if (name != null && name.isNotEmpty) {
                  final newPlaylist =
                      await playlistService.createPlaylist(name);
                  var res = await playlistService.addSongsToPlaylist(
                      newPlaylist.id!, selectedSongIds.toList());
                  Navigator.pop(context);
                  var cnt = selectedSongIds.length;
                  isMultiSelectMode = false;
                  selectedSongIds.clear();
                  if (res != null && !res) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('存在重复添加歌曲！')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加 ${cnt} 首歌到新收藏夹: $name')),
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
                title: Text(playlist.name),
                onTap: () async {
                  var res = await playlistService.addSongsToPlaylist(
                      playlist.id!, selectedSongIds.toList());
                  Navigator.pop(context);
                  var cnt = selectedSongIds.length;
                  isMultiSelectMode = false;
                  selectedSongIds.clear();
                  if (res != null && !res) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('存在重复添加歌曲！')),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('已添加 ${cnt} 首歌到收藏夹: ${playlist.name}')),
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

  // 构建通用的 UI 结构
  @override
  Widget build(BuildContext context) {
    var hasHeader = getHeader() != null;
    return Scaffold(
      extendBodyBehindAppBar: !hasHeader,
      appBar: AppBar(
        title: Text(getPageTitle()),
        backgroundColor: Theme.of(context).primaryColor.withAlpha(220),
        elevation: 0,
        actions: isMultiSelectMode
            ? [
                ElevatedButton.icon(
                  icon: const Icon(Icons.select_all, size: 20),
                  label: const Text('全选'),
                  onPressed: () {
                    setState(() {
                      selectedSongIds.clear();
                      for (var song in loadedSongs) {
                        selectedSongIds.add(song.id!);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('删除'),
                  onPressed: _onDeleteSelected,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_special, size: 20),
                  label: const Text('加入收藏'),
                  onPressed: onAddToFavoritesSelected,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('取消'),
                  onPressed: () => setState(() {
                    isMultiSelectMode = false;
                    selectedSongIds.clear();
                  }),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.select_all, size: 20),
                    label: const Text('多选'),
                    onPressed: () => OnMultiSelection(context),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] +
                getAppBarActions() +
                [SizedBox(width: 8)],
      ),
      body: Container(
        color: Theme.of(context).primaryColor.withOpacity(0.2),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<SongModel>>(
                future: songsFuture,
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
                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return Center(child: Text(getEmptyMessage()));
                  }
                  if (hasHeader) {
                    return ListView.builder(
                      cacheExtent: 2000,
                      controller: _scrollController,
                      itemCount: songs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return getHeader()!;
                        } else {
                          final songIndex = index - 1;
                          return SongListItem(
                            song: songs[songIndex],
                            index: index, // 显示序号从 1 开始
                            onPlay: () => playSong(songs[songIndex]),
                            onToggleFavorite: () =>
                                toggleFavorite(songs[songIndex]),
                            onDelete: () => deleteSong(songs[songIndex]),
                            onAddToNext: () => addToNext(songs[songIndex]),
                            onSelect: () =>
                                toggleSelection(songs[songIndex].id!),
                            isSelected:
                                selectedSongIds.contains(songs[songIndex].id!),
                            isMultiSelectMode: isMultiSelectMode,
                          );
                        }
                      },
                    );
                  } else {
                    return ListView.builder(
                      cacheExtent: 2000,
                      controller: _scrollController,
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        return SongListItem(
                          song: songs[index],
                          index: index + 1, // 显示序号从 1 开始
                          onPlay: () => playSong(songs[index]),
                          onToggleFavorite: () => toggleFavorite(songs[index]),
                          onDelete: () => deleteSong(songs[index]),
                          onAddToNext: () => addToNext(songs[index]),
                          onSelect: () => toggleSelection(songs[index].id!),
                          isSelected:
                              selectedSongIds.contains(songs[index].id!),
                          isMultiSelectMode: isMultiSelectMode,
                        );
                      },
                    );
                  }
                },
              ),
            ),
            // if (hasHeader) getFooter()!, // 根据当前逻辑，只有 hasHeader 时显示 footer
          ],
        ),
      ),
    );
  }

  // 抽象方法：获取页面标题
  String getPageTitle();

  // 抽象方法：获取 AppBar 的 actions
  List<Widget> getAppBarActions() {
    return [];
  }

  // 抽象方法：获取空列表时的提示信息
  String getEmptyMessage();
}
