import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/playlist_service.dart';
import '../services/favorites_service.dart';
import 'package:marquee/marquee.dart';
import '../utils/thumbnail_generator.dart';
import '../views/song_play_page.dart';
import '../utils/tools.dart';
import 'package:just_musica/widgets/volume_controller.dart';
import '../widgets/progress_slider.dart';

// 添加到文件中的其他地方
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class PlaybackControlBar extends StatefulWidget {
  const PlaybackControlBar({
    super.key,
    required this.playlistService,
    required this.favoritesService,
    required this.playbackService,
    required this.onPlaylistsChanged,
  });
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  final PlaybackService playbackService;
  final Function() onPlaylistsChanged;

  @override
  State<PlaybackControlBar> createState() => _PlaybackControlBarState();
}

class _PlaybackControlBarState extends State<PlaybackControlBar> {
  double? _dragValue;
  late ValueNotifier<PlaybackMode> playbackModeNotifier;
  PlaybackMode prevmode = PlaybackMode.loopAll;

  @override
  void initState() {
    super.initState();
    playbackModeNotifier = ValueNotifier(widget.playbackService.playbackMode);
    prevmode = widget.playbackService.playbackMode;
  }

  void _switchPlayBackMode() {
    final nextMode = PlaybackMode.values[
        (playbackModeNotifier.value.index + 1) % PlaybackMode.values.length];
    playbackModeNotifier.value = nextMode;
    widget.playbackService.playbackMode = nextMode;
    widget.playbackService.notifyListeners();
    prevmode = nextMode;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.playbackService.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final song = state?.currentSong;
        if (song == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note,
                          color: Theme.of(context).disabledColor),
                      const SizedBox(width: 8),
                      Text('未播放歌曲',
                          style: TextStyle(
                              color: Theme.of(context).disabledColor)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlaybackProgressBar(playbackService: widget.playbackService),
            Container(
              height: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.15),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  _buildSongInfo(context, song),
                  IconButton(
                    icon: Icon(
                      song.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: song.isFavorite ? Colors.red : null,
                    ),
                    onPressed: () => _toggleFavorite(context, song),
                  ),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: widget.playbackService.previous,
                          ),
                          IconButton(
                            icon: Icon(
                              size: 32,
                              state!.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: state.isPlaying
                                ? widget.playbackService.pause
                                : widget.playbackService.resume,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: widget.playbackService.next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<PlaybackMode>(
                        valueListenable: playbackModeNotifier,
                        builder: (context, mode, child) {
                          IconData icon;
                          String toolstipText;
                          switch (mode) {
                            case PlaybackMode.random:
                              icon = Icons.shuffle;
                              toolstipText = '随机播放';
                              break;
                            case PlaybackMode.singleLoop:
                              icon = Icons.repeat_one;
                              toolstipText = '单曲循环';
                              break;
                            case PlaybackMode.loopAll:
                              icon = Icons.repeat;
                              toolstipText = '循环播放';
                              break;
                            default:
                              icon = Icons.playlist_play;
                              toolstipText = '顺序播放';
                          }
                          return IconButton(
                            icon: Icon(icon),
                            onPressed: _switchPlayBackMode,
                            tooltip: toolstipText,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () =>
                            _showAddToPlaylistDialog(context, song),
                        tooltip: '添加到收藏夹',
                      ),
                      HorizontalVolumeController(
                          playbackService: widget.playbackService),
                      IconButton(
                          onPressed: () => _onTapped(song, context),
                          icon: Icon(Icons.arrow_upward)),
                      SizedBox(width: 8),
                      Text(
                        formatDuration(_dragValue != null
                            ? Duration(seconds: _dragValue!.round())
                            : state.position),
                        style: const TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongInfo(BuildContext context, SongModel song) {
    return SizedBox(
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.grey.withOpacity(0.1),
          splashColor: Theme.of(context).primaryColor.withOpacity(0.2),
          onTap: () => _onTapped(song, context),
          child: Row(
            children: [
              FutureBuilder<ImageProvider>(
                future: ThumbnailGenerator().getThumbnailProvider(song.path),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: snapshot.data!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note, size: 80),
                      ),
                    );
                  }
                  return const Icon(Icons.music_note, size: 80);
                },
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          var tStyle = TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.secondary,
                          );
                          final textSpan = TextSpan(
                            text: song.title ?? '未知曲名',
                            style: tStyle,
                          );
                          final textPainter = TextPainter(
                            text: textSpan,
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                          )..layout(maxWidth: double.infinity);

                          // 只有在文本宽度超过容器宽度时才使用 Marquee
                          if (textPainter.width > constraints.maxWidth) {
                            return Marquee(
                              text: song.title ?? '未知曲名',
                              style: tStyle,
                              scrollAxis: Axis.horizontal,
                              blankSpace: 30,
                              velocity: 50,
                              pauseAfterRound: const Duration(seconds: 1),
                            );
                          } else {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                song.title ?? '未知曲名',
                                style: tStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      height: 25,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          var tStyle = TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).disabledColor,
                          );
                          final textSpan = TextSpan(
                            text: song.artist ?? '未知歌手',
                            style: tStyle,
                          );
                          final textPainter = TextPainter(
                            text: textSpan,
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                          )..layout(maxWidth: double.infinity);

                          // 只有在文本宽度超过容器宽度时才使用 Marquee
                          if (textPainter.width > constraints.maxWidth) {
                            return Marquee(
                              text: song.artist ?? '未知歌手',
                              style: tStyle,
                              scrollAxis: Axis.horizontal,
                              blankSpace: 30,
                              velocity: 50,
                              pauseAfterRound: const Duration(seconds: 1),
                            );
                          } else {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                song.artist ?? '未知歌手',
                                style: tStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, SongModel song) {
    setState(() {
      song.isFavorite = !song.isFavorite;
    });
    widget.favoritesService.toggleFavorite(song.id!);
    widget.playbackService.notifyListeners();
  }

  void _onTapped(SongModel song, BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SongPlayPage(
          song: song,
          playbackService: widget.playbackService,
          favoritesService: widget.favoritesService,
          playlistService: widget.playlistService,
          playbackModeNotifier: playbackModeNotifier,
          onPlaylistsChanged: widget.onPlaylistsChanged,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0); // 从底部开始
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, SongModel song) async {
    final playlists = await widget.playlistService.getPlaylists();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('添加到收藏夹'),
            TextButton(
              onPressed: () async {
                final name = await _showNewPlaylistDialog(context);
                if (name != null && name.trim().isNotEmpty) {
                  final newPlaylist =
                      await widget.playlistService.createPlaylist(name);
                  var res = await widget.playlistService
                      .addSongToPlaylist(newPlaylist.id!, song.id!);
                  Navigator.pop(context);
                  if (res != null && !res) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('存在重复添加歌曲！')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加 ${song.title} 到新收藏夹: $name')),
                  );
                }
              },
              child: const Text('新建收藏'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(playlist.name),
                onTap: () async {
                  var res = await widget.playlistService
                      .addSongToPlaylist(playlist.id!, song.id!);
                  Navigator.pop(context);
                  if (res != null && !res) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('存在重复添加歌曲！')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('已添加 ${song.title} 到收藏夹: ${playlist.name}')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _showNewPlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入收藏夹名称'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
