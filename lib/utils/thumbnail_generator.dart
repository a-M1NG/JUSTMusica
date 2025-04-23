import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import '../services/database_service.dart';

class ThumbnailGenerator {
  // 缩略图尺寸
  static const int _thumbnailSize = 100;
  static final _imageCache = <String, ImageProvider>{};

  Future<ImageProvider> getThumbnailProvider(String songPath) async {
    if (_imageCache.containsKey(songPath)) {
      return _imageCache[songPath]!;
    }

    final filePath = await getThumbnail(songPath);
    if (filePath.isEmpty) {
      return const AssetImage('assets/images/default_cover.jpg');
    }

    final provider = FileImage(File(filePath));
    _imageCache[songPath] = provider;
    return provider;
  }

  Future<Image> getOriginCover(String songPath) async {
    try {
      // 提取歌曲封面
      final tag = await AudioTags.read(songPath);
      final coverData = tag?.pictures.firstOrNull?.bytes;

      if (coverData == null || coverData.isEmpty) {
        return Image.asset('assets/images/default_cover.jpg'); // 默认封面
      }
      // 解码图像
      final image = img.decodeImage(coverData);
      if (image == null) {
        return Image.asset('assets/images/default_cover.jpg'); // 默认封面
      }

      // Convert img.Image to Flutter Image widget
      return Image.memory(Uint8List.fromList(img.encodePng(image)));
    } catch (e) {
      print('获取封面失败: $e');
      return Image.asset('assets/images/default_cover.jpg'); // 默认封面
    }
  }

  /// 获取或生成歌曲封面缩略图（根据歌曲路径）
  Future<String> getThumbnail(String songPath) async {
    try {
      // 生成缩略图文件名（MD5 哈希）
      final fileName = _generateFileName(songPath);
      final thumbDir = await _getThumbnailDirectory();
      final thumbPath = '${thumbDir.path}/$fileName';

      // 检查缩略图是否已存在
      if (await File(thumbPath).exists()) {
        return thumbPath;
      }

      // 提取歌曲封面
      final tag = await AudioTags.read(songPath);
      final coverData = tag?.pictures.firstOrNull?.bytes;

      if (coverData == null || coverData.isEmpty) {
        return ''; // 无封面，返回空字符串
      }

      // 解码图像
      final image = img.decodeImage(coverData);
      if (image == null) {
        return ''; // 解码失败
      }

      // 调整大小
      final thumbnail = img.copyResize(
        image,
        width: _thumbnailSize,
        height: _thumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      // 转换为 jpg，不支持 webp 格式

      final jpgData = img.encodeJpg(thumbnail);

      // 保存缩略图
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(jpgData);

      return thumbPath;
    } catch (e) {
      print('生成缩略图失败: $e');
      return '';
    }
  }

  Future<void> generateThumbnail(String songPath) async {
    try {
      // 生成缩略图文件名（MD5 哈希）
      final fileName = _generateFileName(songPath);
      final thumbDir = await _getThumbnailDirectory();
      final thumbPath = '${thumbDir.path}/$fileName';

      // 检查缩略图是否已存在
      if (await File(thumbPath).exists()) {
        return;
      }

      // 提取歌曲封面
      final tag = await AudioTags.read(songPath);
      final coverData = tag?.pictures.firstOrNull?.bytes;

      if (coverData == null || coverData.isEmpty) {
        return;
      }

      // 解码图像
      final image = img.decodeImage(coverData);
      if (image == null) {
        return; // 解码失败
      }

      // 调整大小
      final thumbnail = img.copyResize(
        image,
        width: _thumbnailSize,
        height: _thumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      // 转换为 jpg，不支持 webp 格式

      final jpgData = img.encodeJpg(thumbnail, quality: 80);

      // 保存缩略图
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(jpgData);
    } catch (e) {
      print('生成缩略图失败: $e');
    }
  }

  /// 获取或生成歌曲封面缩略图（根据歌曲 ID）
  Future<String> getThumbnailById(int songId) async {
    try {
      // 查询歌曲信息
      final song = await DatabaseService().getSongById(songId);
      if (song == null) {
        return ''; // 歌曲不存在
      }

      // 使用歌曲路径生成缩略图
      return await getThumbnail(song.path);
    } catch (e) {
      print('根据 ID 生成缩略图失败: $e');
      return '';
    }
  }

  /// 生成缩略图文件名（MD5 哈希）
  String _generateFileName(String songPath) {
    final bytes = utf8.encode(songPath);
    final hash = md5.convert(bytes).toString();
    return '$hash.webp';
  }

  /// 获取缩略图存储目录
  Future<Directory> _getThumbnailDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${docDir.path}/JUSTMUSIC/thumbs');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }
}
