import 'dart:math';
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

class PlaybackService {
  final windows.AudioPlayer _audioPlayer = windows.AudioPlayer();
  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger();

  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  Stream<PlaybackState> get playbackStateStream => _playbackStateSubject.stream;

  List<SongModel> _currentPlaylist = [];
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
    } catch (e) {
      _logger.e('Failed to resume playback: $e');
      rethrow;
    }
  }

  Future<void> next() async {
    try {
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

  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _playbackMode = mode;
    _updatePlaybackState();
    _logger.i('Playback mode set to $mode');
  }

  Future<void> seekTo(int seconds) async {
    try {
      await _audioPlayer.seek(Duration(seconds: seconds));
      _logger.i('Seeked to $seconds seconds');
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
    } else if (_playbackMode == PlaybackMode.sequential && _currentIndex < _currentPlaylist.length - 1) {
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