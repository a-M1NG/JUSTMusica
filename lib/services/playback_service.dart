import 'dart:convert';
import 'dart:math';
import 'dart:io'; // 用于 Platform.isWindows 检查
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_musica/models/song_model.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:window_size/window_size.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/thumbnail_generator.dart';

// 播放模式枚举
enum PlaybackMode {
  random, // 随机播放
  singleLoop, // 单曲循环
  sequential, // 顺序播放
  loopAll, // 全部循环
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

  // 音量属性，范围 0.0 到 1.0
  double _volume = 1.0;
  double get volume => _volume;
  set volume(double value) {
    setVolume(value);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  int get position =>
      _playbackStateSubject.valueOrNull?.position.inSeconds ?? 0;

  // 音量流
  final _volumeSubject = BehaviorSubject<double>.seeded(1.0);
  Stream<double> get volumeStream => _volumeSubject.stream;
  late SharedPreferences prefs;

  // PlaybackMode 的 getter 和 setter
  PlaybackMode get playbackMode => _playbackMode;
  set playbackMode(PlaybackMode mode) {
    setPlaybackMode(mode);
    _logger.i('Playback mode set to $mode');
    notifyListeners();
  }

  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;
  SongModel get currentSong =>
      _playbackStateSubject.valueOrNull?.currentSong ??
      SongModel(path: "assets/audio/sample.mp3"); // 获取当前播放的歌曲
  List<SongModel> _currentPlaylist = [];
  List<SongModel> _oriPlaylist = [];
  final List<SongModel> _playNextSongs = [];
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  List<SongModel> get currentPlaylist => _playNextSongs + _currentPlaylist;

  PlaybackService() {
    _init();
  }

  get currentSongStream =>
      _playbackStateSubject.stream.map((state) => state.currentSong).distinct();

  void _init() async {
    // 初始化音量
    prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble('volume') ?? 1.0; // 默认音量为 1.0
    _audioPlayer.setVolume(_volume * _volume);
    _volumeSubject.add(_volume); // 初始音量值
    //设置播放模式
    final modeString =
        prefs.getString('playback_mode') ?? 'PlaybackMode.sequential';
    switch (modeString) {
      case 'PlaybackMode.random':
        _playbackMode = PlaybackMode.random;
        break;
      case 'PlaybackMode.singleLoop':
        _playbackMode = PlaybackMode.singleLoop;
        break;
      case 'PlaybackMode.sequential':
        _playbackMode = PlaybackMode.sequential;
        break;
      case 'PlaybackMode.loopAll':
        _playbackMode = PlaybackMode.loopAll;
        break;
      default:
        _playbackMode = PlaybackMode.sequential;
    }
    // 设置最后播放的歌曲
    final lastPlayedSongId = prefs.getInt('last_played_song_id');
    if (lastPlayedSongId != null) {
      _dbService.getSongById(lastPlayedSongId).then((song) async {
        final jsonStr = prefs.getString('playback_list');
        if (jsonStr != null) {
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          _currentPlaylist = jsonList
              .map((json) => SongModel.fromMap(json as Map<String, dynamic>))
              .toList();
          setPlaybackList(_currentPlaylist, song!);
        }
        await playSong(song!, isStart: true);
      }).catchError((error) {
        _logger.e('Failed to load last played song: $error');
      });
    }

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

  /// 设置音量
  /// [value] 音量值，范围 0.0（静音）到 1.0（最大音量）
  Future<void> setVolume(double value) async {
    try {
      // await prefs.setDouble('volume', value); // 保存音量值到本地
      // 确保音量值在 0.0 到 1.0 之间
      _volume = value.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_volume * _volume);
      _volumeSubject.add(_volume); // 通知音量变化
      _logger.i('Volume set to $_volume');
      _updatePlaybackState();
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to set volume to $value: $e');
      rethrow;
    }
  }

  /// 设置播放列表
  ///
  /// [songs] 要设置的歌曲列表
  /// 设置新的播放列表，替换当前的播放列表
  Future<void> setPlaybackList(List<SongModel> songs, SongModel song) async {
    try {
      _currentPlaylist = List.from(songs);
      // final playbackList =
      //     _currentPlaylist.map((song) => song.toMap()).toList();
      // final jsonStr = jsonEncode(playbackList);
      // prefs.setString('playback_list', jsonStr);
      _oriPlaylist = _currentPlaylist.toList();
      if (playbackMode == PlaybackMode.random) {
        _currentPlaylist.shuffle();
        // 把当前播放的歌曲放到列表首
        final index = _currentPlaylist.indexWhere((s) => s.path == song.path);
        if (index != -1) {
          final currentSong = _currentPlaylist.removeAt(index);
          _currentPlaylist.insert(0, currentSong);
          _currentIndex = 0;
        }
      }
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

  Future<void> removeFromPlaylist(int songId) async {
    try {
      final song = await _dbService.getSongById(songId);
      if (song == null) {
        _logger.w('Song with ID $songId not found');
        return;
      }

      _currentPlaylist.removeWhere((s) => s.id == song.id);
      _oriPlaylist.removeWhere((s) => s.id == song.id);
      _logger.i('Removed song "${song.title}" from playlist');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to remove song from playlist: $e');
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
    return List.unmodifiable(currentPlaylist);
  }

  /// 获取当前播放索引
  int getCurrentIndex() {
    return _currentIndex;
  }

  Future<void> playSong(SongModel song,
      {bool fromPlayNext = false, bool isStart = false}) async {
    try {
      // Windows 平台临时检查（可选）
      if (Platform.isWindows) {
        setWindowTitle("${song.title} - ${song.artist}");
        _logger.w('Playing on Windows with audioplayers: ${song.title}');
      }
      await prefs.setInt('last_played_song_id', song.id!);
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
      // 应用当前音量
      if (isStart) {
        await _audioPlayer.pause();
        _logger.i('Prefetching info for song');
        await ThumbnailGenerator().prefetchInfo(song);
        _updatePlaybackState(
          currentSong: song,
          isPlaying: false,
        );
      } else {
        await _audioPlayer.setVolume(_volume * _volume);
        _updatePlaybackState(currentSong: song, isPlaying: true);
        _logger.i('Playing song: ${song.title}');
        // now the thumbservice is running at background as an isolate
        // and will no longer causing lag in UI thread
        // therefore prefetching info will be not necessary.
        // // 预取信息
        // _logger.i('Prefetching info for song');
        // await ThumbnailGenerator().prefetchInfo(song);
        _logger.i('Prefetching info for next song');
        await ThumbnailGenerator().prefetchInfo(
            _currentPlaylist[(_currentIndex + 1) % _currentPlaylist.length]);
        // _logger.i('Prefetching info for previous song');
        // await ThumbnailGenerator().prefetchInfo(_currentPlaylist[
        //     (_currentIndex - 1 + _currentPlaylist.length) %
        //         _currentPlaylist.length]);
        notifyListeners();
      }
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
      if (playbackMode == PlaybackMode.random) {
        if (_currentIndex == _currentPlaylist.length - 1) {
          _currentPlaylist.shuffle();
        }
      }
      _currentIndex = (_currentIndex + 1) % _currentPlaylist.length;

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
      if (playbackMode == PlaybackMode.random) {
        if (_currentIndex == 0) {
          _currentPlaylist.shuffle();
        }
      }
      _currentIndex = (_currentIndex - 1 + _currentPlaylist.length) %
          _currentPlaylist.length;

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
    if (_playbackMode == PlaybackMode.random) {
      _currentPlaylist.shuffle();
      // 把当前播放的歌曲放到列表首
      final index =
          _currentPlaylist.indexWhere((s) => s.path == currentSong.path);
      if (index != -1) {
        final currentSong = _currentPlaylist.removeAt(index);
        _currentPlaylist.insert(0, currentSong);
        _currentIndex = 0;
      }
    } else {
      _currentPlaylist = _oriPlaylist.toList();
      _currentIndex =
          _currentPlaylist.indexWhere((s) => s.path == currentSong.path);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playback_mode', mode.toString());
    // _updatePlaybackState();
    _logger.i('Playback mode set to $mode');
    _updatePlaybackState();
    notifyListeners();
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
      await playSong(_currentPlaylist[_currentIndex]);
      await pause();
      // _updatePlaybackState(isPlaying: false);
      _logger.i('Playback stopped after song completion');
    }
  }

  @override
  void dispose() {
    prefs.setDouble('volume', _volume);
    prefs.setString('playback_mode', _playbackMode.toString());
    _audioPlayer.dispose();
    _playbackStateSubject.close();
    _volumeSubject.close(); // 关闭音量流
    super.dispose();
  }

  Future<void> saveStateToPrefs() async {
    await prefs.reload();
    await prefs.setDouble('volume', _volume);
    await prefs.setString('playback_mode', _playbackMode.toString());
    final playbackList = _currentPlaylist.map((song) => song.toMap()).toList();
    final jsonStr = jsonEncode(playbackList);
    await prefs.setString('playback_list', jsonStr);
  }
}
