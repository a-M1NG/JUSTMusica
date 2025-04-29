import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:just_musica/models/song_model.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import '../services/database_service.dart';

class LRUCache<K, V> {
  final int capacity;
  final Map<K, V> _cache = {};
  final LinkedHashMap<K, bool> _usage = LinkedHashMap<K, bool>();

  LRUCache(this.capacity);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // 更新使用顺序
    _usage.remove(key);
    _usage[key] = true;
    return _cache[key];
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _usage.remove(key);
      _usage[key] = true;
      return;
    }

    // 达到容量上限，移除最久未使用的项
    if (_cache.length >= capacity && _usage.isNotEmpty) {
      final oldestKey = _usage.keys.first;
      _cache.remove(oldestKey);
      _usage.remove(oldestKey);
    }

    _cache[key] = value;
    _usage[key] = true;
  }

  bool containsKey(K key) => _cache.containsKey(key);
  V? operator [](K key) => get(key);
  void operator []=(K key, V value) => put(key, value);
  void clear() {
    _cache.clear();
    _usage.clear();
  }
}

class ThumbnailGenerator {
  // 缩略图尺寸
  static const int _thumbnailSize = 100;
  static const int _thumbnailCacheCapacity = 200;
  static const int _originalCoverCacheCapacity = 20;
  static final _imageCache =
      LRUCache<String, ImageProvider>(_thumbnailCacheCapacity);
  static final _oriImageCache =
      LRUCache<String, Image>(_originalCoverCacheCapacity);
  static final _gradientCache =
      LRUCache<int, LinearGradient?>(_originalCoverCacheCapacity);

  Future<ImageProvider> getThumbnailProvider(String songPath) async {
    final cachedProvider = _imageCache.get(songPath);
    if (cachedProvider != null) {
      return cachedProvider;
    }

    final filePath = await getThumbnail(songPath);
    if (filePath.isEmpty) {
      return const AssetImage('assets/images/default_cover.jpg');
    }

    final provider = FileImage(File(filePath));
    _imageCache[songPath] = provider;
    return provider;
  }

  Future<LinearGradient?> generateGradient(SongModel song) async {
    try {
      final cachedGradient = _gradientCache.get(song.id!);
      if (cachedGradient != null) {
        return cachedGradient;
      }
      final image = await ThumbnailGenerator().getOriginCover(song.path);
      final paletteGenerator =
          await PaletteGenerator.fromImageProvider(image.image);

      final dominantColor =
          paletteGenerator.dominantColor?.color ?? Colors.grey[800]!;
      final vibrantColor =
          paletteGenerator.vibrantColor?.color ?? dominantColor;
      final lightVibrantColor =
          paletteGenerator.lightVibrantColor?.color ?? vibrantColor;

      final res = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          lightVibrantColor.withOpacity(0.8),
          vibrantColor.withOpacity(0.8),
          dominantColor.withOpacity(0.8),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      _gradientCache[song.id!] = res;
      return res;
    } catch (e) {
      debugPrint('Error generating gradient: $e');
      return null;
    }
  }

  Future<Image> getOriginCover(String songPath) async {
    final cachedImage = _oriImageCache.get(songPath);
    if (cachedImage != null) {
      return cachedImage;
    }
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
      final coverImage = Image.memory(Uint8List.fromList(img.encodePng(image)));
      _oriImageCache[songPath] = coverImage;
      // Convert img.Image to Flutter Image widget
      return coverImage;
    } catch (e) {
      print('获取封面失败: $e');
      return Image.asset('assets/images/default_cover.jpg'); // 默认封面
    }
  }

  Future<void> prefetchInfo(SongModel song) async {
    if (song.id == null) {
      debugPrint('无法预加载信息: song.id为空');
      return;
    }

    try {
      // 1. 获取并缓存封面图片
      Image? coverImage;
      final cachedImage = _oriImageCache.get(song.path);

      if (cachedImage == null) {
        final tag = await AudioTags.read(song.path);
        final coverData = tag?.pictures.firstOrNull?.bytes;

        if (coverData == null || coverData.isEmpty) {
          // 设置默认封面
          coverImage = Image.asset('assets/images/default_cover.jpg');
          _oriImageCache[song.path] = coverImage;
        }

        final decodedImage = img.decodeImage(coverData!);
        if (decodedImage == null) {
          debugPrint('封面图片解码失败: ${song.path}');
          return;
        }

        coverImage =
            Image.memory(Uint8List.fromList(img.encodePng(decodedImage)));
        _oriImageCache[song.path] = coverImage;
      } else {
        coverImage = cachedImage;
      }

      // 2. 生成并缓存渐变色
      if (!_gradientCache.containsKey(song.id!)) {
        final paletteGenerator =
            await PaletteGenerator.fromImageProvider(coverImage.image);

        final dominantColor =
            paletteGenerator.dominantColor?.color ?? Colors.grey[800]!;
        final vibrantColor =
            paletteGenerator.vibrantColor?.color ?? dominantColor;
        final lightVibrantColor =
            paletteGenerator.lightVibrantColor?.color ?? vibrantColor;

        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightVibrantColor.withOpacity(0.8),
            vibrantColor.withOpacity(0.8),
            dominantColor.withOpacity(0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        );

        _gradientCache[song.id!] = gradient;
      }
    } catch (e) {
      debugPrint('预加载歌曲信息失败: ${e.toString()}');
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
