import 'package:flutter/material.dart';
import 'package:just_musica/models/playlist_model.dart';
import 'package:just_musica/models/song_model.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:just_musica/services/playlist_service.dart';
import 'package:just_musica/services/service_locator.dart';
import 'package:just_musica/utils/thumbnail_generator.dart';

double dialogMaxWidth = 350;
double dialogMaxHeight = 300;
double coverLen = 48;

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

void CreateMessage(String msg, BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg)),
  );
  return;
}

Widget _buildPlaylistListTile(
  BuildContext context,
  PlaylistModel playlist,
  VoidCallback onTap,
) {
  Future<ImageProvider>? imgProviderFuture;
  if (playlist.songs != null && playlist.songs!.isNotEmpty) {
    final firstSong = playlist.songs!.first;
    // 假设 ThumbnailGenerator 和 getThumbnailProvider 方法可用
    imgProviderFuture =
        ThumbnailGenerator().getThumbnailProvider(firstSong.path);
  }

  return ListTile(
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          "${playlist.songs!.length.toString()}首音乐",
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
      ],
    ),
    minTileHeight: 60,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    ),
    leading: imgProviderFuture != null
        ? FutureBuilder<ImageProvider>(
            future: imgProviderFuture,
            builder: (context, snapshot) {
              return snapshot.hasData
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: snapshot.data!,
                        width: coverLen,
                        height: coverLen,
                        fit: BoxFit.cover,
                      ))
                  : const CircularProgressIndicator();
            })
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
                color: Colors.grey,
                width: coverLen,
                height: coverLen,
                child: const Icon(Icons.music_note, size: 24))),
    onTap: onTap,
  );
}

Future<String?> showNewPlaylistDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('新建收藏夹'),
            content: TextField(
              controller: controller,
              maxLength: 40,
              decoration: const InputDecoration(hintText: '输入收藏夹名称'),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, controller.text.trim()),
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
    },
  );
}

void showAddToPlaylistDialogMultiSelection(
  BuildContext context,
  bool mounted,
  Set<int> selectedSongIds,
  VoidCallback exitMultiSelectMode,
) async {
  await waitForServiceLocator();
  final playlistService = serviceLocator<PlaylistService>();
  final playlists = await playlistService.getPlaylists();
  // ignore: use_build_context_synchronously
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('添加到收藏夹'),
          TextButton(
            onPressed: () async {
              final name = await showNewPlaylistDialog(context);
              if (name != null && name.isNotEmpty) {
                final newPlaylist = await playlistService.createPlaylist(name);
                // ignore: use_build_context_synchronously
                if (!mounted) return;
                Navigator.pop(context); // Close the add to playlist dialog

                var res = await playlistService.addSongsToPlaylist(
                    newPlaylist.id!, selectedSongIds.toList());

                var cnt = selectedSongIds.length;
                exitMultiSelectMode(); // Exits multi-select, clears selection

                if (res != null && !res) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('存在重复添加歌曲！')),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加 $cnt 首歌到新收藏夹: $name')),
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('收藏夹名称不能为空！')),
                );
              }
            },
            child: const Text('新建收藏'),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogMaxWidth,
        height: dialogMaxHeight,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            Future<ImageProvider>? imgProviderFuture;
            if (playlist.songs != null && playlist.songs!.isNotEmpty) {
              final firstSong = playlist.songs!.first;
              // 假设 ThumbnailGenerator 和 getThumbnailProvider 方法可用
              imgProviderFuture =
                  ThumbnailGenerator().getThumbnailProvider(firstSong.path);
            }
            return _buildPlaylistListTile(
              context,
              playlist,
              () async {
                // ignore: use_build_context_synchronously
                if (!mounted) return;
                Navigator.pop(context); // Close the add to playlist dialog
                var res = await playlistService.addSongsToPlaylist(
                    playlist.id!, selectedSongIds.toList());
                var cnt = selectedSongIds.length;
                exitMultiSelectMode(); // Exits multi-select, clears selection
                if (res != null && !res) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('存在重复添加歌曲！')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加 $cnt 首歌到收藏夹: ${playlist.name}')),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

void showAddToPlaylistDialog(BuildContext context, SongModel song,
    {VoidCallback updatePage = DoNothingAction.new}) async {
  await waitForServiceLocator();
  final playlistService = serviceLocator<PlaylistService>();
  final playlists = await playlistService.getPlaylists();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('添加到收藏夹'),
          TextButton(
            onPressed: () async {
              final name = await showNewPlaylistDialog(context);
              if (name != null && name.isNotEmpty) {
                final newPlaylist = await playlistService.createPlaylist(name);
                var res = await playlistService.addSongToPlaylist(
                    newPlaylist.id!, song.id!);
                Navigator.pop(context);
                if (res != null && !res) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('存在重复添加歌曲！')),
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
        width: dialogMaxWidth,
        height: dialogMaxHeight,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            Future<ImageProvider>? imgProviderFuture;
            if (playlist.songs != null && playlist.songs!.isNotEmpty) {
              final firstSong = playlist.songs!.first;
              // 假设 ThumbnailGenerator 和 getThumbnailProvider 方法可用
              imgProviderFuture =
                  ThumbnailGenerator().getThumbnailProvider(firstSong.path);
            }
            return _buildPlaylistListTile(
              context,
              playlist,
              () async {
                var res = await playlistService.addSongToPlaylist(
                    playlist.id!, song.id!);
                Navigator.pop(context);
                if (res != null && !res) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('${song.title} 已存在于收藏夹 ${playlist.name} 中！')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加 ${song.title} 到收藏夹: ${playlist.name}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
  updatePage();
}
