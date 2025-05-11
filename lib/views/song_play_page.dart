import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/lyrics_service.dart';
import '../services/playback_service.dart';
import '../utils/thumbnail_generator.dart';
import '../widgets/lyrics_display.dart';
import '../services/playlist_service.dart';
import '../services/favorites_service.dart';
import 'package:just_musica/widgets/volume_controller.dart';
import '../widgets/progress_slider.dart';
import 'package:just_musica/utils/tools.dart';

class SongPlayPage extends StatefulWidget {
  SongModel song;
  final PlaybackService playbackService;
  final FavoritesService favoritesService;
  final PlaylistService playlistService;
  final ValueNotifier<PlaybackMode> playbackModeNotifier;
  final Function() onPlaylistsChanged;
  SongPlayPage({
    super.key,
    required this.song,
    required this.playbackService,
    required this.favoritesService,
    required this.playlistService,
    required this.playbackModeNotifier,
    required this.onPlaylistsChanged,
  });

  @override
  State<SongPlayPage> createState() => _SongPlayPageState();
}

class _SongPlayPageState extends State<SongPlayPage> {
  late StreamSubscription _currentSongSubscription;
  late Future<String> _lyricsFuture;
  bool _isLoading = true;
  Image? _coverImage;
  LinearGradient? _gradient;
  SongModel? _currentSong;
  PlaybackMode _currentPlayBackMode = PlaybackMode.sequential;

  @override
  void initState() {
    super.initState();
    _currentSongSubscription =
        widget.playbackService.currentSongStream.listen((song) {
      setState(() {
        _currentSong = song;
        _lyricsFuture = LyricsService().getLrcForSong(song);
        _loadAssets(); // Reload assets when song changes
      });
    });
    widget.song = widget.playbackService.currentSong;
    _lyricsFuture = LyricsService().getLrcForSong(widget.song);
    _currentPlayBackMode = widget.playbackService.playbackMode;
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final song = _currentSong ?? widget.song;
    final coverFuture = ThumbnailGenerator().getOriginCover(song.path);
    final gradientFuture = ThumbnailGenerator().generateGradient(song);
    final results = await Future.wait([coverFuture, gradientFuture]);
    if (!mounted) return;
    setState(() {
      _coverImage = results[0] as Image;
      _gradient = results[1] as LinearGradient?;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _currentSongSubscription.cancel();
    super.dispose();
  }

  void _switchPlayBackMode() {
    final nextMode = PlaybackMode.values[
        (widget.playbackModeNotifier.value.index + 1) %
            PlaybackMode.values.length];
    widget.playbackModeNotifier.value = nextMode;
    widget.playbackService.playbackMode = nextMode;
    widget.playbackService.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    // if (_isLoading) {
    //   return const Scaffold(
    //     body: Center(child: CircularProgressIndicator()),
    //   );
    // }

    final currentSong = _currentSong ?? widget.song;
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: _gradient ??
                  LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.6),
                      Theme.of(context).primaryColorDark.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            ),
          ),

          // Content
          Row(
            children: [
              // Left side: Cover and playback controls
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(flex: 1, child: Container()), // Empty space
                      Expanded(
                        flex: 5,
                        child: _buildCover(currentSong),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        flex: 2,
                        child: _buildPlaybackControls(
                          context,
                          widget.playlistService,
                          widget.favoritesService,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right side: Song info and lyrics
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSongInfo(currentSong),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LyricsDisplay(
                          lyricsFuture: _lyricsFuture,
                          onTapLyric: (time) =>
                              widget.playbackService.seekTo(time),
                          playbackService: widget.playbackService,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Back button
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_downward, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(SongModel song) {
    if (_isLoading) {
      return const SizedBox();
    }
    return LayoutBuilder(builder: (context, constraints) {
      final size = min(constraints.maxHeight, constraints.maxWidth);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              offset: const Offset(0, 4),
              blurRadius: 8.0,
            ),
          ],
          image: _coverImage != null
              ? DecorationImage(
                  image: _coverImage!.image,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: null,
      );
    });
  }

  Widget _buildSongInfo(SongModel song) {
    debugPrint("rebuild song info");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title ?? '未知曲名',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.person, size: 20),
            const SizedBox(width: 4),
            Flexible(
              child: OverflowText(
                text: song.artist ?? '未知歌手',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.album, size: 20),
            const SizedBox(width: 4),
            Flexible(
              child: OverflowText(
                text: song.album ?? '未知专辑',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(BuildContext context,
      PlaylistService playlistService, FavoritesService favoritesService) {
    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
        final currentSong = _currentSong ?? widget.song;
        if (currentSong == null) return const SizedBox();
        final position = state?.position ?? Duration.zero;
        final duration = state?.duration ?? Duration.zero;
        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: PlaybackProgressBar(
                        playbackService: widget.playbackService),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                ValueListenableBuilder<PlaybackMode>(
                  valueListenable: widget.playbackModeNotifier,
                  builder: (context, mode, child) {
                    IconData icon;
                    switch (mode) {
                      case PlaybackMode.random:
                        icon = Icons.shuffle;
                        break;
                      case PlaybackMode.singleLoop:
                        icon = Icons.repeat_one;
                        break;
                      case PlaybackMode.loopAll:
                        icon = Icons.repeat;
                        break;
                      default:
                        icon = Icons.playlist_play;
                    }
                    return IconButton(
                      icon: Icon(icon),
                      onPressed: _switchPlayBackMode,
                    );
                  },
                ),
                VolumeController(playbackService: widget.playbackService),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 24),
                  onPressed: () {
                    _isLoading = true;
                    widget.playbackService.previous();
                    // _loadAssets();
                  },
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                  onPressed: isPlaying
                      ? widget.playbackService.pause
                      : widget.playbackService.resume,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 24),
                  onPressed: () {
                    _isLoading = true;
                    widget.playbackService.next();
                    // _loadAssets();
                  },
                ),
                IconButton(
                  icon: Icon(
                    currentSong.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: currentSong.isFavorite ? Colors.red : null,
                    size: 24,
                  ),
                  onPressed: () =>
                      _toggleFavorite(favoritesService, currentSong),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add, size: 24),
                  onPressed: () =>
                      showAddToPlaylistDialog(context, widget.song),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _toggleFavorite(FavoritesService favoritesService, SongModel song) {
    song.isFavorite = !song.isFavorite;
    favoritesService.toggleFavorite(song.id!);
  }
}

class OverflowText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  const OverflowText({
    required this.text,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 创建 TextPainter 来测量文本宽度
        final span = TextSpan(text: text, style: style);
        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        tp.layout(); // 不设置 maxWidth，获取文本自然宽度

        final naturalWidth = tp.width;
        // 如果文本自然宽度超过可用宽度，则认为会溢出
        if (naturalWidth > constraints.maxWidth) {
          return Tooltip(
            message: text, // tooltip 显示完整文本
            child: Text(
              text,
              style: style,
              overflow: overflow,
              maxLines: maxLines,
            ),
          );
        } else {
          return Text(
            text,
            style: style,
            maxLines: maxLines,
          );
        }
      },
    );
  }
}
