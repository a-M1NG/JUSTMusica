import 'dart:math';
import 'package:just_audio/just_audio.dart'; // 用于音频播放
import 'package:just_musica/models/song_model.dart'; // SongModel 定义
import 'package:just_musica/services/database_service.dart'; // 数据库服务
import 'package:logger/logger.dart'; // 可选：日志记录
import 'package:rxdart/rxdart.dart'; // 用于状态流

// 播放模式枚举
enum PlaybackMode {
  random,      // 随机播放
  singleLoop,  // 单曲循环
  sequential,  // 顺序播放
  loopAll,     // 列表循环
}

// 播放状态类
class PlaybackState {
  final SongModel? currentSong; // 当前歌曲
  final Duration position;      // 当前播放位置
  final Duration duration;      // 歌曲总时长
  final bool isPlaying;         // 是否正在播放
  final PlaybackMode mode;      // 当前播放模式

  PlaybackState({
    this.currentSong,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.mode = PlaybackMode.sequential,
  });
}

class PlaybackService {
  final AudioPlayer _audioPlayer = AudioPlayer(); // 音频播放器
  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger(); // 可选：日志记录

  // 播放状态流
  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;

  // 当前播放列表和索引
  List<SongModel> _currentPlaylist = [];
  int _currentIndex = -1;

  // 当前播放模式
  PlaybackMode _playbackMode = PlaybackMode.sequential;

  PlaybackService() {
    _init();
  }

  // 初始化播放服务
  void _init() {
    // 监听播放状态变化
    _audioPlayer.positionStream.listen((position) {
      _updatePlaybackState(position: position);
    });

    // 监听总时长变化
    _audioPlayer.durationStream.listen((duration) {
      _updatePlaybackState(duration: duration ?? Duration.zero);
    });

    // 监听播放状态（播放/暂停）
    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      } else {
        _updatePlaybackState(isPlaying: isPlaying);
      }
    });

    // 初始状态
    _updatePlaybackState();
  }

  // 更新播放状态
  void _updatePlaybackState({
    SongModel? currentSong,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
  }) {
    final currentState = _playbackStateSubject.valueOrNull ?? PlaybackState();
    _playbackStateSubject.add(PlaybackState(
      currentSong: currentSong ?? currentState.currentSong,
      position: position ?? currentState.position,
      duration: duration ?? currentState.duration,
      isPlaying: isPlaying ?? currentState.isPlaying,
      mode: _playbackMode,
    ));
  }

  /// 播放指定歌曲
  Future<void> playSong(SongModel song) async {
    try {
      // 如果当前播放列表为空，加载所有歌曲
      if (_currentPlaylist.isEmpty) {
        _currentPlaylist = await _dbService.getAllSongs();
      }

      // 查找歌曲在播放列表中的索引
      _currentIndex = _currentPlaylist.indexWhere((s) => s.path == song.path);
      if (_currentIndex == -1) {
        // 如果歌曲不在当前播放列表中，添加到列表
        _currentPlaylist.add(song);
        _currentIndex = _currentPlaylist.length - 1;
      }

      // 设置播放源并播放
      await _audioPlayer.setFilePath(song.path);
      await _audioPlayer.play();
      _updatePlaybackState(currentSong: song, isPlaying: true);
      _logger.i('Playing song: ${song.title}');
    } catch (e) {
      _logger.e('Failed to play song ${song.title}: $e');
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _updatePlaybackState(isPlaying: false);
      _logger.i('Playback paused');
    } catch (e) {
      _logger.e('Failed to pause playback: $e');
      rethrow;
    }
  }

  /// 继续播放
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
      _updatePlaybackState(isPlaying: true);
      _logger.i('Playback resumed');
    } catch (e) {
      _logger.e('Failed to resume playback: $e');
      rethrow;
    }
  }

  /// 播放下一曲
  Future<void> next() async {
    try {
      if (_currentPlaylist.isEmpty) {
        _logger.w('Playlist is empty');
        return;
      }

      // 根据播放模式选择下一首歌
      if (_playbackMode == PlaybackMode.random) {
        _currentIndex = Random().nextInt(_currentPlaylist.length);
      } else {
        _currentIndex = (_currentIndex + 1) % _currentPlaylist.length;
      }

      final nextSong = _currentPlaylist[_currentIndex];
      await playSong(nextSong);
      _logger.i('Playing next song: ${nextSong.title}');
    } catch (e) {
      _logger.e('Failed to play next song: $e');
      rethrow;
    }
  }

  /// 播放上一曲
  Future<void> previous() async {
    try {
      if (_currentPlaylist.isEmpty) {
        _logger.w('Playlist is empty');
        return;
      }

      // 根据播放模式选择上一首歌
      if (_playbackMode == PlaybackMode.random) {
        _currentIndex = Random().nextInt(_currentPlaylist.length);
      } else {
        _currentIndex = (_currentIndex - 1 + _currentPlaylist.length) % _currentPlaylist.length;
      }

      final previousSong = _currentPlaylist[_currentIndex];
      await playSong(previousSong);
      _logger.i('Playing previous song: ${previousSong.title}');
    } catch (e) {
      _logger.e('Failed to play previous song: $e');
      rethrow;
    }
  }

  /// 设置播放模式
  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _playbackMode = mode;
    _updatePlaybackState();
    _logger.i('Playback mode set to $mode');
  }

  /// 跳转到指定时间
  Future<void> seekTo(int seconds) async {
    try {
      await _audioPlayer.seek(Duration(seconds: seconds));
      _logger.i('Seeked to $seconds seconds');
    } catch (e) {
      _logger.e('Failed to seek to $seconds seconds: $e');
      rethrow;
    }
  }

  // 处理歌曲播放完成
  Future<void> _handleSongCompletion() async {
    if (_playbackMode == PlaybackMode.singleLoop) {
      // 单曲循环：重新播放当前歌曲
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } else if (_playbackMode == PlaybackMode.loopAll) {
      // 列表循环：播放下一首
      await next();
    } else if (_playbackMode == PlaybackMode.sequential && _currentIndex < _currentPlaylist.length - 1) {
      // 顺序播放：如果未到最后一首，播放下一首
      await next();
    } else if (_playbackMode == PlaybackMode.random) {
      // 随机播放：随机选择下一首
      await next();
    } else {
      // 其他情况：停止播放
      await _audioPlayer.stop();
      _updatePlaybackState(isPlaying: false);
      _logger.i('Playback stopped after song completion');
    }
  }

  // 释放资源
  void dispose() {
    _audioPlayer.dispose();
    _playbackStateSubject.close();
  }
}