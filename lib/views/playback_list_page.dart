import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';
import '../widgets/song_list_item.dart';
import 'base_music_page.dart';

class PlaybackListPage extends SongListPageBase {
  const PlaybackListPage({
    super.key,
    required super.favoritesService,
    required super.playbackService,
  });

  @override
  State<PlaybackListPage> createState() => _PlaybackListPageState();
}

class _PlaybackListPageState extends SongListPageBaseState<PlaybackListPage> {
  @override
  Future<List<SongModel>> loadSongsImplementation() {
    return widget.playbackService.getPlaybackList();
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final confirm = await showDeleteDialog(
      context,
      '移除歌曲',
      '是否从播放列表中移除此歌曲？',
    );
    if (confirm == true) {
      await widget.playbackService.removeFromPlaylist(song.id!);
      await loadSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playbackService,
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
        await widget.playbackService.removeFromPlaylist(songId);
      }
      await loadSongs();
    }
    return confirm;
  }
}
