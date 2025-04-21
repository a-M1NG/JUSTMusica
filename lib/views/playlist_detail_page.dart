import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/playlist_service.dart';
import '../widgets/song_list_item.dart';

class PlaylistDetailPage extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Future<List<SongModel>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = PlaylistService().getPlaylistSongs(widget.playlist.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
      ),
      body: FutureBuilder<List<SongModel>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载...'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final songs = snapshot.data ?? [];
          if (songs.isEmpty) {
            return const Center(child: Text('此收藏夹为空'));
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              return SongListItem(
                song: songs[index],
                index: index + 1,
                onPlay: () => _playSong(songs[index]),
                onToggleFavorite: () => _toggleFavorite(songs[index]),
                onDelete: () => _removeFromPlaylist(songs[index]),
                onAddToNext: () => _addToNext(songs[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _playSong(SongModel song) {
    PlaybackService().setPlaybackList([song]);
    PlaybackService().playSong(song);
  }

  void _addToNext(SongModel song) {
    PlaybackService().playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    FavoritesService().toggleFavorite(song.id!);
    setState(() {
      _songsFuture = PlaylistService().getPlaylistSongs(widget.playlist.id!);
    });
  }

  void _removeFromPlaylist(SongModel song) async {
    final confirm = await _showRemoveDialog(context);
    if (confirm == true) {
      await PlaylistService()
          .removeSongFromPlaylist(widget.playlist.id!, song.id!);
      setState(() {
        _songsFuture = PlaylistService().getPlaylistSongs(widget.playlist.id!);
      });
    }
  }

  Future<bool?> _showRemoveDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从收藏夹中移除'),
        content: const Text('是否从此收藏夹中移除此歌曲？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}
