import 'dart:io';
import 'package:audiotags/audiotags.dart'; // 用于提取音乐元数据
import 'package:path/path.dart' as p; // 处理文件路径
import 'package:just_musica/models/song_model.dart'; // SongModel 定义
import 'package:just_musica/services/database_service.dart'; // 数据库服务
import 'package:logger/logger.dart'; // 可选：日志记录

class MusicScannerService {
  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger(); // 可选：日志记录

  // 支持的音乐文件扩展名
  static const List<String> _supportedExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
  ];

  /// 扫描指定路径下的音乐文件，返回歌曲列表
  Future<List<SongModel>> scanMusic(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        _logger.w('Directory does not exist: $path');
        throw Exception('Directory does not exist: $path');
      }

      final List<SongModel> songs = [];
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File &&
            _supportedExtensions
                .contains(p.extension(entity.path).toLowerCase())) {
          final song = await _createSongModelFromFile(entity);
          if (song != null) {
            songs.add(song);
          }
        }
      }

      _logger.i('Scanned ${songs.length} music files in $path');
      return songs;
    } catch (e) {
      _logger.e('Failed to scan music in $path: $e');
      rethrow;
    }
  }

  /// 导入指定路径的歌曲文件到数据库
  Future<void> importSongs(List<String> paths) async {
    try {
      final List<SongModel> songsToImport = [];

      // 遍历路径，提取元数据并创建 SongModel
      for (var filePath in paths) {
        final file = File(filePath);
        if (await file.exists() &&
            _supportedExtensions
                .contains(p.extension(filePath).toLowerCase())) {
          final song = await _createSongModelFromFile(file);
          if (song != null) {
            songsToImport.add(song);
          }
        } else {
          _logger.w(
              'File does not exist or is not a supported music file: $filePath');
        }
      }

      // 批量插入到数据库
      if (songsToImport.isNotEmpty) {
        await _dbService.batchInsertSongs(songsToImport);
        _logger.i('Imported ${songsToImport.length} songs to database');
      } else {
        _logger.w('No valid songs to import');
      }
    } catch (e) {
      _logger.e('Failed to import songs: $e');
      rethrow;
    }
  }

  /// 从文件中提取元数据并创建 SongModel
  Future<SongModel?> _createSongModelFromFile(File file) async {
    try {
      final tag = await AudioTags.read(file.path);
      if (tag == null) {
        _logger.w('No metadata found for file: ${file.path}');
        // 创建默认 SongModel，即使无元数据
        return SongModel(
          path: file.path,
          title: p.basenameWithoutExtension(file.path),
          artist: '未知艺术家',
          album: null,
          duration: null, // 可通过 just_audio 获取时长
          coverPath: null,
          isFavorite: false,
        );
      }
      return SongModel(
        path: file.path,
        title: tag.title?.isNotEmpty == true
            ? tag.title
            : p.basenameWithoutExtension(file.path),
        artist: tag.trackArtist?.isNotEmpty == true ? tag.trackArtist : '未知艺术家',
        album: tag.album?.isNotEmpty == true ? tag.album : null,
        duration: tag.duration,
        coverPath: null,
        isFavorite: false,
      );
    } catch (e) {
      _logger.e('Failed to create SongModel from file ${file.path}: $e');
      // 异常时也创建默认 SongModel
      return SongModel(
        path: file.path,
        title: p.basenameWithoutExtension(file.path),
        artist: '未知艺术家',
        album: null,
        duration: null,
        coverPath: null,
        isFavorite: false,
      );
    }
  }
}
