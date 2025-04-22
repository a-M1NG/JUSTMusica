import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/playlist_service.dart';
import '../widgets/song_list_item.dart';
import '../services/playback_service.dart';
import '../services/favorites_service.dart';
import '../utils/thumbnail_generator.dart';

class PlaylistDetailPage extends StatefulWidget {
  final PlaylistModel playlist;
  final PlaylistService playlistService;
  final FavoritesService favoritesService;
  final PlaybackService playbackService;
  const PlaylistDetailPage({
    super.key,
    required this.playlist,
    required this.playlistService,
    required this.favoritesService,
    required this.playbackService,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Future<List<SongModel>> _songsFuture;
  ImageProvider? _coverImage;

  @override
  void initState() {
    super.initState();
    _songsFuture = _loadSongs();
  }

  Future<List<SongModel>> _loadSongs() async {
    final songs =
        await widget.playlistService.getPlaylistSongs(widget.playlist.id!);
    // 加载最新歌曲封面
    if (songs.isNotEmpty) {
      final latestSong = songs[0];
      try {
        final image =
            await ThumbnailGenerator().getOriginCover(latestSong.path);
        setState(() {
          _coverImage = image.image;
        });
      } catch (e) {
        _coverImage = null;
      }
    }
    return songs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 封面和歌单信息区域
          _buildPlaylistHeader(),
          // 歌曲列表
          Expanded(
            child: FutureBuilder<List<SongModel>>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图片
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: _coverImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: _coverImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.music_note, size: 40, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          // 歌单信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlist.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<SongModel>>(
                  future: _songsFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    return Text(
                      '$count 首歌曲',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: widget.playlist.name);
    ImageProvider? newCoverImage = _coverImage;
    bool coverChanged = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单'),
        content: SizedBox(
          height: 200,
          child: Row(
            children: [
              // 封面图片
              GestureDetector(
                onTap: () async {
                  // 这里可以添加选择新封面的逻辑
                  // 例如: 从相册选择或拍照
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: newCoverImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: newCoverImage,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.music_note,
                              size: 40, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // 编辑表单
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '歌单名称',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                // await widget.playlistService.updatePlaylist(
                //   widget.playlist.id!,
                //   newName,
                //   // 这里可以传递新的封面路径
                // );
                // setState(() {
                //   if (coverChanged) {
                //     _coverImage = newCoverImage;
                //   }
                // });
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _playSong(SongModel song) async {
    widget.playbackService.setPlaybackList(
        await widget.playlistService.getPlaylistSongs(widget.playlist.id!));
    widget.playbackService.playSong(song);
  }

  void _addToNext(SongModel song) {
    widget.playbackService.playNext(song.id!);
  }

  void _toggleFavorite(SongModel song) {
    widget.favoritesService.toggleFavorite(song.id!);
    setState(() {
      song.isFavorite = !song.isFavorite;
    });
  }

  void _removeFromPlaylist(SongModel song) async {
    final confirm = await _showRemoveDialog(context);
    if (confirm == true) {
      await widget.playlistService
          .removeSongFromPlaylist(widget.playlist.id!, song.id!);
      setState(() {
        _songsFuture = _loadSongs();
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
