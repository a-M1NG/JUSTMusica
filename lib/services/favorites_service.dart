import 'package:just_musica/models/song_model.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

class FavoritesService {
  final Database _database; // 数据库实例，由外部传入
  final Logger _logger = Logger();

  FavoritesService(this._database);

  /// 获取我喜欢的歌曲列表
  Future<List<SongModel>> getFavoriteSongs() async {
    try {
      final List<Map<String, dynamic>> maps = await _database.query(
        'songs',
        where: 'is_favorite = ?',
        whereArgs: [1],
      );
      final favorites = maps.map((map) => SongModel.fromMap(map)).toList();
      _logger.i('Fetched ${favorites.length} favorite songs');
      return favorites;
    } catch (e) {
      _logger.e('Failed to fetch favorite songs: $e');
      rethrow;
    }
  }

  /// 切换歌曲的喜欢状态
  Future<void> toggleFavorite(int songId) async {
    try {
      // 检查歌曲是否存在
      final songResult = await _database.query(
        'songs',
        where: 'id = ?',
        whereArgs: [songId],
      );

      if (songResult.isEmpty) {
        throw Exception('Song with ID $songId does not exist');
      }

      final currentSong = SongModel.fromMap(songResult.first);
      final newFavoriteStatus = currentSong.isFavorite ? 0 : 1;

      await _database.update(
        'songs',
        {'is_favorite': newFavoriteStatus},
        where: 'id = ?',
        whereArgs: [songId],
      );

      _logger
          .i('Toggled favorite status for song $songId to $newFavoriteStatus');
    } catch (e) {
      _logger.e('Failed to toggle favorite for song $songId: $e');
      rethrow;
    }
  }
}
