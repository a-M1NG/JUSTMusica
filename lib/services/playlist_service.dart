import 'package:just_musica/models/song_model.dart';
import 'package:just_musica/models/playlist_model.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

class PlaylistService {
  final Database _database;
  final Logger _logger = Logger();

  PlaylistService(this._database);

  /// 获取所有收藏夹
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      final List<Map<String, dynamic>> maps = await _database.query(
        'Playlists',
        orderBy: 'created_at DESC',
      );
      final playlists = maps.map((map) => PlaylistModel.fromMap(map)).toList();
      _logger.i('Fetched ${playlists.length} playlists');
      return playlists;
    } catch (e) {
      _logger.e('Failed to fetch playlists: $e');
      rethrow;
    }
  }

  /// 创建新收藏夹，可选封面路径
  Future<PlaylistModel> createPlaylist(String name, {String? coverPath}) async {
    try {
      final playlist = PlaylistModel(
        id: null,
        name: name,
        createdAt: DateTime.now(),
        coverPath: coverPath,
        songs: [],
      );

      final id = await _database.insert(
        'Playlists',
        playlist.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final createdPlaylist = PlaylistModel(
        id: id,
        name: name,
        createdAt: playlist.createdAt,
        coverPath: coverPath,
        songs: [],
      );

      _logger.i('Created playlist: $createdPlaylist');
      return createdPlaylist;
    } catch (e) {
      _logger.e('Failed to create playlist "$name": $e');
      rethrow;
    }
  }

  /// 将歌曲添加到收藏夹
  Future<bool?> addSongToPlaylist(int playlistId, int songId) async {
    try {
      // 检查收藏夹是否存在
      final playlistExists = await _database.query(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      if (playlistExists.isEmpty) {
        throw Exception('Playlist with ID $playlistId does not exist');
      }

      // 检查歌曲是否存在
      final songExists = await _database.query(
        'Songs',
        where: 'id = ?',
        whereArgs: [songId],
      );
      if (songExists.isEmpty) {
        throw Exception('Song with ID $songId does not exist');
      }

      // 检查歌曲是否已在收藏夹中
      final songInPlaylist = await _database.query(
        'PlaylistSongs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
      );
      if (songInPlaylist.isNotEmpty) {
        _logger.w('Song $songId is already in playlist $playlistId');
        return false; // 歌曲已在收藏夹中
      }

      // 添加关联
      await _database.insert(
        'PlaylistSongs',
        {
          'playlist_id': playlistId,
          'song_id': songId,
          'added_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 如果封面为空，尝试更新收藏夹封面为歌曲封面
      final playlist = await _database.query(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      if (playlist.isNotEmpty && playlist.first['cover_path'] == null) {
        final song = await _database.query(
          'Songs',
          where: 'id = ?',
          whereArgs: [songId],
        );
        if (song.isNotEmpty && song.first['cover_path'] != null) {
          await _database.update(
            'Playlists',
            {'cover_path': song.first['cover_path']},
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        }
      }

      _logger.i('Added song $songId to playlist $playlistId');
      return true;
    } catch (e) {
      _logger.e('Failed to add song $songId to playlist $playlistId: $e');
      rethrow;
    }
  }

  Future<bool?> addSongsToPlaylist(int playlistID, List<int> songIds) async {
    try {
      bool allAdded = true;
      for (var songId in songIds) {
        var res = await addSongToPlaylist(playlistID, songId);
        if (res == false) {
          allAdded = false;
        }
      }
      _logger.i('Added ${songIds.length} songs to playlist $playlistID');
      return allAdded;
    } catch (e) {
      _logger.e('Failed to add songs to playlist $playlistID: $e');
      rethrow;
    }
  }

  /// 从收藏夹移除歌曲
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      final deleted = await _database.delete(
        'PlaylistSongs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
      );

      if (deleted == 0) {
        _logger.w('No song $songId found in playlist $playlistId to remove');
      } else {
        _logger.i('Removed song $songId from playlist $playlistId');
      }

      // 检查是否需要更新封面
      final playlist = await _database.query(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      if (playlist.isNotEmpty) {
        final currentCoverPath = playlist.first['cover_path'] as String?;
        final song = await _database.query(
          'Songs',
          where: 'id = ?',
          whereArgs: [songId],
        );
        if (song.isNotEmpty && currentCoverPath == song.first['cover_path']) {
          // 查找最新的歌曲封面
          final remainingSongs = await _database.query(
            'PlaylistSongs',
            where: 'playlist_id = ?',
            whereArgs: [playlistId],
            orderBy: 'added_at DESC',
            limit: 1,
          );
          if (remainingSongs.isNotEmpty) {
            final latestSongId = remainingSongs.first['song_id'] as int;
            final latestSong = await _database.query(
              'Songs',
              where: 'id = ?',
              whereArgs: [latestSongId],
            );
            await _database.update(
              'Playlists',
              {
                'cover_path': latestSong.isNotEmpty
                    ? latestSong.first['cover_path']
                    : null
              },
              where: 'id = ?',
              whereArgs: [playlistId],
            );
          } else {
            await _database.update(
              'Playlists',
              {'cover_path': null},
              where: 'id = ?',
              whereArgs: [playlistId],
            );
          }
        }
      }
    } catch (e) {
      _logger.e('Failed to remove song $songId from playlist $playlistId: $e');
      rethrow;
    }
  }

  Future<void> removeSongsFromPlaylist(
      int playlistId, List<int> songIds) async {
    try {
      await _database.transaction((txn) async {
        for (var songId in songIds) {
          await txn.delete(
            'PlaylistSongs',
            where: 'playlist_id = ? AND song_id = ?',
            whereArgs: [playlistId, songId],
          );
        }
      });
    } catch (e) {
      _logger.e('Failed to remove songs from playlist: $e');
      rethrow;
    }
  }

  /// 删除收藏夹
  Future<void> deletePlaylist(int playlistId) async {
    try {
      final deleted = await _database.delete(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      if (deleted == 0) {
        _logger.w('No playlist with ID $playlistId found to delete');
      } else {
        _logger.i('Deleted playlist $playlistId');
      }
    } catch (e) {
      _logger.e('Failed to delete playlist $playlistId: $e');
      rethrow;
    }
  }

  /// 获取收藏夹歌曲列表，支持排序（"added_at" 或 "title"）
  Future<List<SongModel>> getPlaylistSongs(int playlistId,
      {String? sortBy}) async {
    try {
      // 验证收藏夹是否存在
      final playlistExists = await _database.query(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      if (playlistExists.isEmpty) {
        throw Exception('Playlist with ID $playlistId does not exist');
      }

      // 构建排序条件
      String orderBy;
      switch (sortBy?.toLowerCase()) {
        case 'title':
          orderBy = 's.title ASC';
          break;
        case 'added_at':
        default:
          orderBy = 'ps.added_at DESC';
          break;
      }

      // 关联查询 PlaylistSongs 和 Songs 表
      final List<Map<String, dynamic>> maps = await _database.rawQuery('''
        SELECT s.* 
        FROM Songs s
        JOIN PlaylistSongs ps ON s.id = ps.song_id
        WHERE ps.playlist_id = ?
        ORDER BY $orderBy
      ''', [playlistId]);

      final songs = maps.map((map) => SongModel.fromMap(map)).toList();
      _logger.i('Fetched ${songs.length} songs for playlist $playlistId');
      return songs;
    } catch (e) {
      _logger.e('Failed to fetch songs for playlist $playlistId: $e');
      rethrow;
    }
  }
}
