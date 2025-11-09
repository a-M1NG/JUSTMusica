import 'package:just_musica/services/database_service.dart';
import 'package:just_musica/services/service_locator.dart';
import 'base_music_page.dart';
import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/playlist_service.dart';
import '../utils/thumbnail_generator.dart';
import '../widgets/playback_control_bar.dart';
import '../utils/tools.dart';

class PlaylistDetailPage extends SongListPageBase {
  final PlaylistModel playlist;

  const PlaylistDetailPage({
    super.key,
    required this.playlist,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState
    extends SongListPageBaseState<PlaylistDetailPage> {
  late final PlaylistService _playlistService;
  ImageProvider? _coverImage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    await waitForServiceLocator();
    if (mounted) {
      _playlistService = serviceLocator<PlaylistService>();
      // Reload after service initialization
      loadSongs();
    }
  }

  @override
  void didUpdateWidget(PlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playlist.id != oldWidget.playlist.id) {
      // 收藏夹ID变化时，重新加载歌曲
      setState(() {
        loadSongs();
        _coverImage = null; // 清空封面图，重新加载
      });
    }
  }

  @override
  Future<List<SongModel>> loadSongsImplementation() async {
    debugPrint("load songs for playlist ${widget.playlist.id}");
    final songs =
        await _playlistService.getPlaylistSongs(widget.playlist.id!);
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
    debugPrint("get songs for playlist ${widget.playlist.id}: ${songs.length}");
    return songs;
  }

  @override
  Future<void> deleteSong(SongModel song) async {
    final confirm = await showDialog<bool>(
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
    if (confirm == true) {
      await _playlistService
          .removeSongFromPlaylist(widget.playlist.id!, song.id!);
      setState(() {
        loadSongs();
      });
    }
  }

  @override
  String getPageTitle() => widget.playlist.name;

  @override
  List<Widget> getAppBarActions() => [
        ElevatedButton.icon(
          icon: const Icon(Icons.edit, size: 20),
          label: const Text('编辑'),
          onPressed: _showEditDialog,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ];

  @override
  String getEmptyMessage() => '此收藏夹为空';

  @override
  Widget getHeader() => _buildPlaylistHeader();

  Widget _buildPlaylistHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: _coverImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(image: _coverImage!, fit: BoxFit.cover),
                  )
                : const Center(
                    child:
                        Icon(Icons.music_note, size: 40, color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlist.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<SongModel>>(
                  future: songsFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    return Text('$count 首歌曲',
                        style: Theme.of(context).textTheme.titleMedium);
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单'),
        content: SizedBox(
          height: 200,
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  // 可添加选择新封面的逻辑
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
                          child: Image(image: newCoverImage, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Icon(Icons.music_note,
                              size: 40, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: nameController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                      labelText: '歌单名称', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _playlistService
                    .updatePlaylistName(widget.playlist.id!, newName);
                widget.playlist.name = newName;
                Navigator.pop(context);
                setState(() {});
                CreateMessage("歌单名称已更新为: \"$newName\"", context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Future<bool?> onDeleteSelected() async {
    final confirm = await showDeleteDialog(
      context,
      '移除歌曲',
      '是否从收藏夹中移除这些歌曲？',
    );
    if (confirm == true) {
      _playlistService.removeSongsFromPlaylist(
        widget.playlist.id!,
        selectedSongIds.toList(),
      );
      CreateMessage("已成功移除${selectedSongIds.length}首歌曲", context);
      await loadSongs();
    }
    return confirm;
  }
}
