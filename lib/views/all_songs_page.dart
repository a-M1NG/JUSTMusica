import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/music_scanner_service.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';
import '../widgets/song_list_item.dart';
import 'base_music_page.dart';

class AllSongsPage extends SongListPageBase {
  final DatabaseService databaseService;

  const AllSongsPage({
    super.key,
    required this.databaseService,
    required super.favoritesService,
    required super.playbackService,
  });

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends SongListPageBaseState<AllSongsPage> {
  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return widget.databaseService.getAllSongs();
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final shouldDeleteFile = await showDeleteDialog(
      context,
      '删除歌曲',
      '是否删除本地歌曲文件？',
    );
    if (shouldDeleteFile == null) return;
    if (shouldDeleteFile == true) {
      await widget.databaseService.deleteSong(song.id!, deleteFile: true);
      await loadSongs();
    } else if (shouldDeleteFile == false) {
      await widget.databaseService.deleteSong(song.id!, deleteFile: false);
      await loadSongs();
    }
  }

  @override
  Future<bool?> showDeleteDialog(
      BuildContext context, String title, String content) {
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      var songList = await MusicScannerService().scanMusic(result);
      await widget.databaseService.batchInsertSongs(songList);
      await loadSongs();
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
      await loadSongs();
    }
  }

  @override
  String getPageTitle() => '';

  @override
  List<Widget> getAppBarActions() => [
        ElevatedButton.icon(
          icon: const Icon(Icons.folder, size: 20),
          label: const Text('导入文件夹'),
          onPressed: _importFolder,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.music_note, size: 20),
          label: const Text('导入歌曲'),
          onPressed: _importSongs,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ];

  @override
  String getEmptyMessage() => '暂无歌曲，请导入音乐';

  @override
  Future<bool?> onDeleteSelected() async {
    final shouldDeleteFile = await showDeleteDialog(
      context,
      '删除歌曲',
      '是否删除本地歌曲文件？',
    );
    if (shouldDeleteFile == null) return null;
    if (shouldDeleteFile == true) {
      await widget.databaseService
          .deleteSongs(selectedSongIds.toList(), deleteFile: true);
      await loadSongs();
    } else if (shouldDeleteFile == false) {
      await widget.databaseService
          .deleteSongs(selectedSongIds.toList(), deleteFile: false);
      await loadSongs();
    }
    return shouldDeleteFile;
  }
}
