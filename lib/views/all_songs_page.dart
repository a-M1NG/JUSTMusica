import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_musica/utils/thumbnail_generator.dart';
import '../models/song_model.dart';
import '../services/database_service.dart';
import '../services/music_scanner_service.dart';
import '../services/service_locator.dart';
import 'base_music_page.dart';
import '../widgets/Thumb_dialog.dart';

class AllSongsPage extends SongListPageBase {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends SongListPageBaseState<AllSongsPage> {
  late final DatabaseService _databaseService;

  @override
  void initState() {
    _databaseService = serviceLocator<DatabaseService>();
    super.initState();
  }

  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return _databaseService.getAllSongs();
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
      await _databaseService.deleteSong(song.id!, deleteFile: true);
      await loadSongs();
    } else if (shouldDeleteFile == false) {
      await _databaseService.deleteSong(song.id!, deleteFile: false);
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
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    // 扫描进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ImportProgressDialog(),
    );
    List<SongModel> songList;
    try {
      songList = await serviceLocator<MusicScannerService>().scanMusic(folderPath);
      for (var song in songList) {
        await _databaseService.insertSong(song);
      }
    } finally {
      Navigator.of(context).pop();
    }
    await loadSongs();
  }

  Future<void> _importSongs() async {
    final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac']);
    if (result != null) {
      final paths =
          result.paths.where((path) => path != null).cast<String>().toList();
      await serviceLocator<MusicScannerService>().importSongs(paths);
      final progressController = StreamController<int>();
      int currentProgress = 0;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ThumbnailGenerationDialog(
          totalSongs: paths.length,
          progressStream: progressController.stream,
        ),
      );
      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        await ThumbnailGenerator().generateThumbnail(path);
        currentProgress = i + 1;
        progressController.add(currentProgress);
        // 添加微小延迟确保UI更新
        await Future.delayed(Duration.zero);
      }
      progressController.close();

      Navigator.of(context).pop();
      await loadSongs();
    }
  }

  @override
  String getPageTitle() => '所有歌曲';

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
      await _databaseService
          .deleteSongs(selectedSongIds.toList(), deleteFile: true);
      await loadSongs();
    } else if (shouldDeleteFile == false) {
      await _databaseService
          .deleteSongs(selectedSongIds.toList(), deleteFile: false);
      await loadSongs();
    }
    return true;
  }
}
