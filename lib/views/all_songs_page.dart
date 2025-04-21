import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/music_scanner_service.dart';
import '../widgets/song_list_item.dart';
import '../services/playback_service.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  late Future<List<SongModel>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = DatabaseService().getAllSongs();
  }

  Future<void> _importFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await MusicScannerService().scanMusic(result);
      setState(() {
        _songsFuture = DatabaseService().getAllSongs();
      });
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
      setState(() {
        _songsFuture = DatabaseService().getAllSongs();
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
                icon: SvgPicture.asset('assets/icons/folder.svg',
                    width: 20, height: 20),
                label: const Text('导入文件夹'),
                onPressed: _importFolder,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: SvgPicture.asset('assets/icons/music_note.svg',
                    width: 20, height: 20),
                label: const Text('导入歌曲'),
                onPressed: _importSongs,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
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
      ],
    );
  }

  void _playSong(SongModel song) {
    // 调用后端接口播放歌曲并设置播放列表
    PlaybackService().setPlaybackList([song]);
    PlaybackService().playSong(song);
  }

  void _addToNext(SongModel song) {
    // 调用后端接口将歌曲加入下一首播放
    PlaybackService().playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    // 调用后端接口切换喜欢状态
    FavoritesService().toggleFavorite(song.id!);
    setState(() {
      _songsFuture = DatabaseService().getAllSongs();
    });
  }

  void _deleteSong(SongModel song) async {
    final shouldDeleteFile = await _showDeleteDialog(context);
    if (shouldDeleteFile != null) {
      // 调用后端接口删除歌曲
      await DatabaseService()
          .deleteSong(song.id!, deleteFile: shouldDeleteFile);
      setState(() {
        _songsFuture = DatabaseService().getAllSongs();
      });
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
