import 'dart:math';
import 'dart:io'; // 用于 Platform.isWindows 检查
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // 替换 just_audio 为 audioplayers
import 'package:just_musica/models/song_model.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

// 播放模式枚举
enum PlaybackMode {
  random,
  singleLoop,
  sequential,
  loopAll,
}

// 播放状态类
class PlaybackState {
  final SongModel? currentSong;
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  PlaybackState({
    this.currentSong,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });
}

class PlaybackService extends ChangeNotifier {
  final AudioPlayer _audioPlayer =
      AudioPlayer(); // 使用 audioplayers 的 AudioPlayer
  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger();
  //PlaybackMode的getter和setter:
  PlaybackMode get playbackMode => _playbackMode;
  set playbackMode(PlaybackMode mode) {
    _playbackMode = mode;
    // _updatePlaybackState();
    // notifyListeners();
  }

  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;
  SongModel get currentSong =>
      _playbackStateSubject.valueOrNull?.currentSong ??
      SongModel(path: "assets/audio/sample.mp3"); // 获取当前播放的歌曲
  List<SongModel> _currentPlaylist = [];
  List<SongModel> _playNextSongs = [];
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  List<SongModel> get currentPlaylist => _playNextSongs + _currentPlaylist;
  PlaybackService() {
    _init();
  }

  get currentSongStream =>
      _playbackStateSubject.stream.map((state) => state.currentSong).distinct();

  void _init() {
    // 监听播放位置
    _audioPlayer.onPositionChanged.listen((position) {
      _updatePlaybackState(position: position);
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _updatePlaybackState(duration: duration);
    });

    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final isPlaying = state == PlayerState.playing;
      _updatePlaybackState(isPlaying: isPlaying);
    });

    // 监听歌曲完成
    _audioPlayer.onPlayerComplete.listen((_) {
      _handleSongCompletion();
    });

    _updatePlaybackState();
  }

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
      // mode: _playbackMode,
    ));
  }

  /// 设置播放列表
  ///
  /// [songs] 要设置的歌曲列表
  /// 设置新的播放列表，替换当前的播放列表
  Future<void> setPlaybackList(List<SongModel> songs) async {
    try {
      _currentPlaylist = List.from(songs);
      _logger.i('Set playback list with ${songs.length} songs');

      // 如果列表不为空但没有设置当前索引，则设置为第一首
      if (_currentPlaylist.isNotEmpty && _currentIndex == -1) {
        _currentIndex = 0;
      }

      notifyListeners();
    } catch (e) {
      _logger.e('Failed to set playback list: $e');
      rethrow;
    }
  }

  /// 将歌曲添加到下一首播放
  ///
  /// [songId] 要添加的歌曲ID
  Future<void> playNext(int songId) async {
    try {
      final song = await _dbService.getSongById(songId);
      if (song == null) {
        _logger.w('Song with ID $songId not found');
        return;
      }

      _playNextSongs.add(song);
      _logger.i('Added song "${song.title}" to play next');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to add song to play next: $e');
      rethrow;
    }
  }

  /// 获取当前播放列表
  Future<List<SongModel>> getPlaybackList() async {
    return List.unmodifiable(_currentPlaylist);
  }

  /// 获取当前播放索引
  int getCurrentIndex() {
    return _currentIndex;
  }

  Future<void> playSong(SongModel song, {bool fromPlayNext = false}) async {
    try {
      // Windows 平台临时检查（可选）
      if (Platform.isWindows) {
        _logger.w('Playing on Windows with audioplayers: ${song.title}');
      }

      if (_currentPlaylist.isEmpty) {
        _currentPlaylist = await _dbService.getAllSongs();
      }

      if (!fromPlayNext) {
        _currentIndex = _currentPlaylist.indexWhere((s) => s.path == song.path);
        if (_currentIndex == -1) {
          _currentPlaylist.add(song);
          _currentIndex = _currentPlaylist.length - 1;
        }
      }

      // 使用 audioplayers 播放本地文件
      await _audioPlayer.play(DeviceFileSource(song.path));
      _updatePlaybackState(currentSong: song, isPlaying: true);
      _logger.i('Playing song: ${song.title}');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to play song ${song.title}: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _updatePlaybackState(isPlaying: false);
      _logger.i('Playback paused');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to pause playback: $e');
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
      _updatePlaybackState(isPlaying: true);
      _logger.i('Playback resumed');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to resume playback: $e');
      rethrow;
    }
  }

  Future<void> next() async {
    try {
      // 先从 playNextSongs 中取出歌曲，优先播放
      if (_playNextSongs.isNotEmpty) {
        final nextSong = _playNextSongs.removeAt(0);
        await playSong(nextSong, fromPlayNext: true);
        _logger.i('Playing next song from playNextSongs: ${nextSong.title}');
        return;
      }

      if (_currentPlaylist.isEmpty) {
        _logger.w('Playlist is empty');
        return;
      }

      if (_playbackMode == PlaybackMode.random) {
        final tmp = _currentIndex;
        // 随机选择一个索引，确保不重复
        while (tmp == _currentIndex) {
          _currentIndex = Random().nextInt(_currentPlaylist.length);
        }
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

  Future<void> previous() async {
    try {
      if (_currentPlaylist.isEmpty) {
        _logger.w('Playlist is empty');
        return;
      }

      if (_playbackMode == PlaybackMode.random) {
        _currentIndex = Random().nextInt(_currentPlaylist.length);
      } else {
        _currentIndex = (_currentIndex - 1 + _currentPlaylist.length) %
            _currentPlaylist.length;
      }

      final previousSong = _currentPlaylist[_currentIndex];
      await playSong(previousSong);
      _logger.i('Playing previous song: ${previousSong.title}');
    } catch (e) {
      _logger.e('Failed to play previous song: $e');
      rethrow;
    }
  }

  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _playbackMode = mode;
    // _updatePlaybackState();
    _logger.i('Playback mode set to $mode');
    // notifyListeners();
  }

  Future<void> seekTo(int seconds) async {
    try {
      await _audioPlayer.seek(Duration(seconds: seconds));
      _logger.i('Seeked to $seconds seconds');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to seek to $seconds seconds: $e');
      rethrow;
    }
  }

  Future<void> seeking(int pos) async {
    _updatePlaybackState(
      position: Duration(seconds: pos),
    );
    notifyListeners();
  }

  Future<void> _handleSongCompletion() async {
    if (_playbackMode == PlaybackMode.singleLoop) {
      // await _audioPlayer.seek(Duration.zero);
      // await _audioPlayer.resume();
      final currsong = _currentPlaylist[_currentIndex];
      await playSong(currsong);
      _logger.i('Playing song in single loop: ${currsong.title}');
    } else if (_playbackMode == PlaybackMode.loopAll) {
      await next();
    } else if (_playbackMode == PlaybackMode.sequential &&
        _currentIndex < _currentPlaylist.length - 1) {
      await next();
    } else if (_playbackMode == PlaybackMode.random) {
      await next();
    } else {
      await _audioPlayer.stop();
      _updatePlaybackState(isPlaying: false);
      _logger.i('Playback stopped after song completion');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _playbackStateSubject.close();
    super.dispose();
  }
}
