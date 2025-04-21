import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as windows;
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
  final PlaybackMode mode;

  PlaybackState({
    this.currentSong,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.mode = PlaybackMode.sequential,
  });
}

class PlaybackService extends ChangeNotifier {
  final windows.AudioPlayer _audioPlayer = windows.AudioPlayer();
  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger();

  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;

  List<SongModel> _currentPlaylist = [];
  List<SongModel> _playNextSongs = [];
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.sequential;

  PlaybackService() {
    _init();
  }

  void _init() {
    _audioPlayer.positionStream.listen((position) {
      _updatePlaybackState(position: position);
    });

    _audioPlayer.durationStream.listen((duration) {
      _updatePlaybackState(duration: duration ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      if (state.processingState == windows.ProcessingState.completed) {
        _handleSongCompletion();
      } else {
        _updatePlaybackState(isPlaying: isPlaying);
      }
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
      mode: _playbackMode,
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

  Future<void> playSong(SongModel song) async {
    try {
      if (_currentPlaylist.isEmpty) {
        _currentPlaylist = await _dbService.getAllSongs();
      }

      _currentIndex = _currentPlaylist.indexWhere((s) => s.path == song.path);
      if (_currentIndex == -1) {
        _currentPlaylist.add(song);
        _currentIndex = _currentPlaylist.length - 1;
      }

      await _audioPlayer.setFilePath(song.path);
      await _audioPlayer.play();
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
      await _audioPlayer.play();
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
      // 先从playNextSongs中取出歌曲, 优先播放
      if (_playNextSongs.isNotEmpty) {
        final nextSong = _playNextSongs.removeAt(0);
        await playSong(nextSong);
        _logger.i('Playing next song from playNextSongs: ${nextSong.title}');
        return;
      }

      if (_currentPlaylist.isEmpty) {
        _logger.w('Playlist is empty');
        return;
      }

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
    _updatePlaybackState();
    _logger.i('Playback mode set to $mode');
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

  Future<void> _handleSongCompletion() async {
    if (_playbackMode == PlaybackMode.singleLoop) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
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
  }
}
