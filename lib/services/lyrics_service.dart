import 'dart:io';
import 'package:just_musica/models/song_model.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

// 歌词行模型
class LrcLine {
  final double time; // 时间（秒）
  final String text; // 歌词内容

  LrcLine({required this.time, required this.text});

  @override
  String toString() => '[${time.toStringAsFixed(2)}] $text';
}

class LyricsService {
  final Logger _logger = Logger();

  /// 解析 LRC 歌词内容，返回歌词行列表
  Future<List<LrcLine>> parseLrc(String lrcContent) async {
    try {
      final lines = lrcContent.split('\n');
      final List<LrcLine> lrcLines = [];

      // 正则表达式匹配时间戳 [mm:ss.xx]
      final RegExp timeRegExp = RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]');

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // 检查是否包含时间戳
        final match = timeRegExp.firstMatch(line);
        if (match == null) {
          // 忽略没有时间戳的行（可能是元数据，如 [ti:标题]）
          continue;
        }

        // 提取时间戳和歌词内容
        final timeStr = match.group(0)!; // 例如 [00:12.34]
        final text = line.substring(match.end).trim();

        // 解析时间戳为秒
        final time = _parseTime(timeStr);
        if (time != null && text.isNotEmpty) {
          lrcLines.add(LrcLine(time: time, text: text));
        }
      }

      // 按时间排序
      lrcLines.sort((a, b) => a.time.compareTo(b.time));
      _logger.i('Parsed ${lrcLines.length} LRC lines');
      return lrcLines;
    } catch (e) {
      _logger.e('Failed to parse LRC content: $e');
      return [];
    }
  }

  /// 检测并返回歌曲的 LRC 歌词内容，无则返回空字符串
  Future<String> getLrcForSong(SongModel song) async {
    try {
      // 假设 LRC 文件与歌曲文件同名，扩展名为 .lrc
      final songPath = song.path;
      final lrcPath = p.setExtension(songPath, '.lrc');
      final lrcFile = File(lrcPath);

      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        _logger.i('Found LRC file for song: ${song.title} at $lrcPath');
        return content;
      } else {
        _logger.w('No LRC file found for song: ${song.title} at $lrcPath');
        return '';
      }
    } catch (e) {
      _logger.e('Failed to get LRC for song ${song.title}: $e');
      return '';
    }
  }

  /// 解析时间戳 [mm:ss.xx] 为秒数
  double? _parseTime(String timeStr) {
    try {
      // 移除方括号，例如 [00:12.34] -> 00:12.34
      final cleanTimeStr = timeStr.replaceAll(RegExp(r'[\[\]]'), '');
      final parts = cleanTimeStr.split(':');
      if (parts.length != 2) return null;

      final minutes = int.parse(parts[0]);
      final seconds = double.parse(parts[1]);
      return minutes * 60 + seconds;
    } catch (e) {
      _logger.e('Failed to parse time $timeStr: $e');
      return null;
    }
  }
}