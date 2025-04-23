import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/music_scanner_service.dart';
import '../widgets/song_list_item.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage(
      {super.key,
      required this.favoritesService,
      required this.databaseService,
      required this.playbackService});
  final FavoritesService favoritesService;
  final DatabaseService databaseService;
  final PlaybackService playbackService;
  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  late Future<List<SongModel>> _songsFuture;
  List<SongModel> _loadedSongs = []; // 存储已加载的歌曲列表

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  // 加载歌曲并缓存
  Future<void> _loadSongs() async {
    debugPrint("Loading songs...");
    _songsFuture = widget.databaseService.getAllSongs();
    // 当歌曲加载完成后，保存到本地变量中
    _songsFuture.then((songs) {
      setState(() {
        _loadedSongs = songs;
      });
      debugPrint("Loaded songs: ${_loadedSongs.length}");
    });
  }

  Future<void> _importFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      var songList = await MusicScannerService().scanMusic(result);
      widget.databaseService.batchInsertSongs(songList);
      _loadSongs(); // 重新加载歌曲列表
    }
  }

  Future<void> _importSongs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );
    if (result != null) {
      final paths =
          result.paths.where((path) => path != null).cast<String>().toList();
      await MusicScannerService().importSongs(paths);
      _loadSongs(); // 重新加载歌曲列表
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 让 body 延伸到 AppBar 后面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 透明背景
        elevation: 0, // 去掉阴影
        // title: const Text('所有歌曲'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.folder, size: 20),
            label: const Text('导入文件夹'),
            onPressed: _importFolder,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: Icon(Icons.music_note, size: 20),
            label: const Text('导入歌曲'),
            onPressed: _importSongs,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        // 保证背景色/主题色仍然可见
        color: Theme.of(context).primaryColor.withOpacity(0.2),
        // 给内容一个 SafeArea.top 的偏移，否则会被状态栏遮挡
        // padding: EdgeInsets.only(
        //   top: kToolbarHeight + MediaQuery.of(context).padding.top,
        // ),
        child: FutureBuilder<List<SongModel>>(
          future: _songsFuture,
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
              return const Center(child: Text('暂无歌曲，请导入音乐'));
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                return SongListItem(
                  song: songs[index],
                  index: index + 1,
                  onPlay: () => _playSong(songs[index]),
                  onToggleFavorite: () => _toggleFavorite(songs[index]),
                  onDelete: () => _deleteSong(songs[index]),
                  onAddToNext: () => _addToNext(songs[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _playSong(SongModel song) async {
    // 直接使用已加载的歌曲列表，不再重复访问数据库
    widget.playbackService.setPlaybackList(_loadedSongs);
    widget.playbackService.playSong(song);
  }

  void _addToNext(SongModel song) {
    // 调用后端接口将歌曲加入下一首播放
    widget.playbackService.playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    // 调用后端接口切换喜欢状态
    final newFavoriteStatus = !song.isFavorite;

    // 立即更新UI状态（乐观更新）
    setState(() {
      song.isFavorite = newFavoriteStatus;
    });
    widget.favoritesService.toggleFavorite(song.id!);
    // _loadSongs(); // 重新加载歌曲列表以更新UI
  }

  void _deleteSong(SongModel song) async {
    final shouldDeleteFile = await _showDeleteDialog(context);
    if (shouldDeleteFile != null) {
      // 调用后端接口删除歌曲
      await DatabaseService()
          .deleteSong(song.id!, deleteFile: shouldDeleteFile);
      _loadSongs(); // 重新加载歌曲列表
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌曲'),
        content: const Text('是否删除本地歌曲文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('仅从列表删除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除文件'),
          ),
        ],
      ),
    );
  }
}
