import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/service_locator.dart';
import '../services/playback_service.dart';
import 'base_music_page.dart';

class PlaybackListPage extends SongListPageBase {
  const PlaybackListPage({super.key});

  @override
  State<PlaybackListPage> createState() => _PlaybackListPageState();
}

class _PlaybackListPageState extends SongListPageBaseState<PlaybackListPage> {
  late final PlaybackService _playbackService;

  @override
  void initState() {
    _playbackService = serviceLocator<PlaybackService>();
    super.initState();
  }

  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return _playbackService.getPlaybackList();
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final confirm = await showDeleteDialog(
      context,
      '移除歌曲',
      '是否从播放列表中移除此歌曲？',
    );
    if (confirm == true) {
      await _playbackService.removeFromPlaylist(song.id!);
      await loadSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playbackService,
      builder: (context, _) => super.build(context),
    );
  }

  @override
  String getPageTitle() => '播放列表';

  @override
  List<Widget> getAppBarActions() => [];

  @override
  String getEmptyMessage() => '播放列表为空';

  @override
  Future<bool?> onDeleteSelected() async {
    final confirm = await showDeleteDialog(
      context,
      '移除歌曲',
      '是否从播放列表中移除这些歌曲？',
    );
    if (confirm == true) {
      for (final songId in selectedSongIds) {
        await _playbackService.removeFromPlaylist(songId);
      }
      await loadSongs();
    }
    return confirm;
  }
}
