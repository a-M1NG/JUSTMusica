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
  SongModel
      song; // Initial song, playbackService.currentSong will be the source of truth after init
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
  Image? _coverImage;
  LinearGradient? _gradient;
  SongModel?
      _currentSongDisplaying; // The song whose assets are currently displayed or being loaded

  // To keep track of the load operation for the current song
  String? _currentLoadingSongPath;

  @override
  void initState() {
    super.initState();
    _currentSongDisplaying = widget.playbackService.currentSong ?? widget.song;
    _lyricsFuture = LyricsService().getLrcForSong(_currentSongDisplaying!);
    _loadAssetsForSong(_currentSongDisplaying!);

    _currentSongSubscription =
        widget.playbackService.currentSongStream.listen((newSong) {
      if (mounted) {
        // When a new song comes from the stream, this is the new target.
        // Immediately update the song model and lyrics future.
        // Set cover and gradient to null to show loading/placeholder state.
        setState(() {
          _currentSongDisplaying = newSong;
          _lyricsFuture = LyricsService().getLrcForSong(newSong);
          _coverImage = null; // Clear old cover
          _gradient = null; // Clear old gradient
        });
        _loadAssetsForSong(newSong); // Start loading assets for the new song
      }
    });
    // _currentPlayBackMode = widget.playbackService.playbackMode; // Already available via playbackModeNotifier
  }

  Future<void> _loadAssetsForSong(SongModel song) async {
    // Tag this loading operation with the song's path (or any unique ID)
    final String songPathToLoad = song.path;
    _currentLoadingSongPath = songPathToLoad;

    // Optionally, set a more specific loading state if not relying on null _coverImage
    // if (mounted) {
    //   setState(() {
    //     // _isLoadingCover = true; // If you have a specific flag for cover loading
    //   });
    // }

    try {
      final coverFuture = ThumbnailGenerator().getOriginCover(song.path);
      final gradientFuture = ThumbnailGenerator().generateGradient(song);

      final results = await Future.wait([coverFuture, gradientFuture]);

      // CRITICAL CHECK: Only update UI if this load is still for the current song
      // and the widget is still mounted.
      if (!mounted || _currentLoadingSongPath != songPathToLoad) {
        // This means another song was selected while this one was loading,
        // or the widget was disposed. So, discard these results.
        return;
      }

      setState(() {
        _coverImage = results[0] as Image?;
        _gradient = results[1] as LinearGradient?;
        // _isLoadingCover = false; // Reset specific loading flag
      });
    } catch (e) {
      print("Error loading assets for ${song.title}: $e");
      if (mounted && _currentLoadingSongPath == songPathToLoad) {
        // Handle error for the current song (e.g., show default cover)
        setState(() {
          _coverImage = null; // Or a default error image
          _gradient = null; // Or a default error gradient
          // _isLoadingCover = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _currentSongSubscription.cancel();
    _currentLoadingSongPath = null; // Clear the path on dispose
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
    // Use _currentSongDisplaying as the song for UI elements.
    // This song is updated via initState and the stream listener.
    final SongModel songForUI = _currentSongDisplaying!;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: _gradient ?? // Use loaded gradient or a default
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
                        child: _buildCover(
                            songForUI), // Pass the current song for UI
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        flex: 2,
                        child: _buildPlaybackControls(
                          context,
                          widget.playlistService,
                          widget.favoritesService,
                          songForUI, // Pass the current song for UI
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
                      _buildSongInfo(songForUI), // Pass the current song for UI
                      const SizedBox(height: 16),
                      Expanded(
                        child: LyricsDisplay(
                          lyricsFuture:
                              _lyricsFuture, // Updated in stream listener
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
    // song parameter is the one currently intended for display
    // If _coverImage is null, it means it's loading or failed to load.
    // Show a placeholder in this case.
    if (_coverImage == null) {
      return LayoutBuilder(builder: (context, constraints) {
        final size = min(constraints.maxHeight, constraints.maxWidth);
        return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[800], // Darker placeholder for themed apps
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: const Offset(0, 4),
                  blurRadius: 8.0,
                ),
              ],
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ));
      });
    }
    // Otherwise, display the loaded cover image.
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
          image: DecorationImage(
            image: _coverImage!.image,
            fit: BoxFit.cover,
          ),
        ),
      );
    });
  }

  Widget _buildSongInfo(SongModel song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title ?? '未知曲名',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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

  Widget _buildPlaybackControls(
      BuildContext context,
      PlaylistService playlistService,
      FavoritesService favoritesService,
      SongModel currentSong // Use the passed currentSong
      ) {
    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
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
                    // No need to set _isLoading here.
                    // The stream listener will update _currentSongDisplaying and trigger _loadAssetsForSong.
                    widget.playbackService.previous();
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
                    widget.playbackService.next();
                  },
                ),
                IconButton(
                  icon: Icon(
                    currentSong.isFavorite // Use the passed currentSong
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
