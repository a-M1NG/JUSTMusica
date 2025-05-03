- [x] playlist添加了CoverPath，默认使用最后一首歌的封面作为封面图，也可以自定义，为此需要更新数据库相关表和接口

- [x] 添加机制，只加载可见部分列表的歌曲略缩图（或歌曲项songlistitem），而不是全部加载
完成一半，可以试试预加载，现在都是先显示骨架屏，等加载完再显示列表，体验不好
- [x] 完成主题切换功能
- [ ] 完成歌词功能
- [x] 添加音量修改和调整播放顺序功能
- [x] 给playlistservice添加更新信息功能，包含封面图路径信息和歌单名称的接口
- [ ] (可选) 添加歌曲列表多选功能 
- [x] (可选) 在数据库中添加表项记录上次播放的歌曲，音量，播放列表，主题

问题：收藏夹服务新建收藏夹没有考虑同名，要不要添加同名约束？


可以不缓存thumb，直接算，用await getCover.then()=> return img
参考 coriandor_player:/lib/library/audio_library.dart里面的具体实现

  /// 读取音乐文件的图片，自动适应缩放
  Future<ImageProvider?> _getResizedPic({
    required int width,
    required int height,
  }) async {
    final ratio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    return getPictureFromPath(
      path: path,
      width: (width * ratio).round(),
      height: (height * ratio).round(),
    ).then((pic) {
      if (pic == null) return null;

      return MemoryImage(pic);
    });
  }

  /// 缓存ImageProvider而不是Uint8List（bytes）
  /// 缓存bytes时，每次加载图片都要重新解码，内存占用很大。快速滚动时能到700mb
  /// 缓存ImageProvider不用重新解码。快速滚动时最多250mb
  /// 48*48
  Future<ImageProvider?> get cover {
    if (_cover == null) {
      return _getResizedPic(width: 48, height: 48).then((value) {
        if (value == null) return null;

        _cover = value;
        return _cover;
      });
    }
    return Future.value(_cover);
  }

  /// audio detail page 不需要频繁调用，所以不缓存图片
  /// 200 * 200
  Future<ImageProvider?> get mediumCover =>
      _getResizedPic(width: 200, height: 200);

  /// now playing 不需要频繁调用，所以不缓存图片
  /// size: 400 * devicePixelRatio（屏幕缩放大小）
  Future<ImageProvider?> get largeCover =>
      _getResizedPic(width: 400, height: 400);