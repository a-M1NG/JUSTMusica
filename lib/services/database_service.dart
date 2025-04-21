import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:logger/logger.dart';

import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/settings_model.dart';

class DatabaseService {
  static Database? _database;
  static const String dbName = 'justmusic.db';
  final Logger _logger = Logger();

  static void init() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'JUSTMUSIC', 'db', dbName);
      await Directory(dirname(path)).create(recursive: true);
      return await openDatabase(
        path,
        version: 2, // 升级版本号以支持迁移
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON'); // 启用外键支持
        },
      );
    } catch (e) {
      _logger.e('Failed to initialize database: $e');
      rethrow;
    }
  }

  // 创建表结构
  Future<void> _onCreate(Database db, int version) async {
    try {
      // 创建 Songs 表
      await db.execute('''
        CREATE TABLE Songs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          path TEXT NOT NULL UNIQUE,
          title TEXT,
          artist TEXT,
          album TEXT,
          duration INTEGER,
          cover_path TEXT,
          is_favorite BOOLEAN DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE Playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          cover_path TEXT
        )
      ''');

      // 创建 PlaylistSongs 表
      await db.execute('''
        CREATE TABLE PlaylistSongs (
          playlist_id INTEGER,
          song_id INTEGER,
          added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (playlist_id, song_id),
          FOREIGN KEY (playlist_id) REFERENCES Playlists(id) ON DELETE CASCADE,
          FOREIGN KEY (song_id) REFERENCES Songs(id) ON DELETE CASCADE
        )
      ''');

      // 创建 Settings 表
      await db.execute('''
        CREATE TABLE Settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      // 创建索引以提高查询性能
      await db.execute('CREATE INDEX idx_songs_path ON Songs(path)');
      await db.execute('CREATE INDEX idx_playlistsongs_added_at ON PlaylistSongs(added_at)');
    } catch (e) {
      _logger.e('Failed to create tables: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE Playlists ADD COLUMN cover_path TEXT');
        _logger.i('Added cover_path column to Playlists table');
      } catch (e) {
        _logger.e('Failed to upgrade database: $e');
        rethrow;
      }
    }
  }

  // --- Songs 表操作 ---

  // 插入歌曲
  Future<void> insertSong(SongModel song) async {
    final db = await database;
    try {
      await db.insert(
        'Songs',
        song.toMap()..removeWhere((key, value) => key == 'id' && value == null),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Failed to insert song: $e');
      rethrow;
    }
  }

  // 批量插入歌曲
  Future<void> batchInsertSongs(List<SongModel> songs) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var song in songs) {
        await txn.insert(
          'Songs',
          song.toMap()..removeWhere((key, value) => key == 'id' && value == null),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // 查询所有歌曲
  Future<List<SongModel>> getAllSongs() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Songs',
        orderBy: 'title ASC',
      );
      return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
    } catch (e) {
      _logger.e('Failed to get all songs: $e');
      rethrow;
    }
  }

  // 根据 ID 查询歌曲
  Future<SongModel?> getSongById(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Songs',
        where: 'id = ?',
        whereArgs: [id],
      );
      return maps.isNotEmpty ? SongModel.fromMap(maps[0]) : null;
    } catch (e) {
      _logger.e('Failed to get song by ID: $e');
      rethrow;
    }
  }

  // 更新歌曲
  Future<void> updateSong(SongModel song) async {
    final db = await database;
    try {
      await db.update(
        'Songs',
        song.toMap(),
        where: 'id = ?',
        whereArgs: [song.id],
      );
    } catch (e) {
      _logger.e('Failed to update song: $e');
      rethrow;
    }
  }

  // 删除歌曲
  Future<void> deleteSong(int songId, {bool deleteFile = false}) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // 删除歌曲
        await txn.delete(
          'Songs',
          where: 'id = ?',
          whereArgs: [songId],
        );
        // 删除关联的播放列表歌曲
        await txn.delete(
          'PlaylistSongs',
          where: 'song_id = ?',
          whereArgs: [songId],
        );
      });

      // 可选：删除文件
      if (deleteFile) {
        final song = await getSongById(songId);
        if (song != null && await File(song.path).exists()) {
          await File(song.path).delete();
        }
      }
    } catch (e) {
      _logger.e('Failed to delete song: $e');
      rethrow;
    }
  }

  // --- Playlists 表操作 ---

  // 插入播放列表
  Future<void> insertPlaylist(PlaylistModel playlist) async {
    final db = await database;
    try {
      await db.insert(
        'Playlists',
        playlist.toMap()..removeWhere((key, value) => key == 'id' && value == null),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Failed to insert playlist: $e');
      rethrow;
    }
  }

  // 查询所有播放列表
  Future<List<PlaylistModel>> getAllPlaylists() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Playlists',
        orderBy: 'created_at DESC',
      );
      return List.generate(maps.length, (i) => PlaylistModel.fromMap(maps[i]));
    } catch (e) {
      _logger.e('Failed to get all playlists: $e');
      rethrow;
    }
  }

  // 根据 ID 查询播放列表
  Future<PlaylistModel?> getPlaylistById(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Playlists',
        where: 'id = ?',
        whereArgs: [id],
      );
      return maps.isNotEmpty ? PlaylistModel.fromMap(maps[0]) : null;
    } catch (e) {
      _logger.e('Failed to get playlist by ID: $e');
      rethrow;
    }
  }

  // 更新播放列表
  Future<void> updatePlaylist(PlaylistModel playlist) async {
    final db = await database;
    try {
      await db.update(
        'Playlists',
        playlist.toMap(),
        where: 'id = ?',
        whereArgs: [playlist.id],
      );
    } catch (e) {
      _logger.e('Failed to update playlist: $e');
      rethrow;
    }
  }

  // 删除播放列表
  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    try {
      await db.delete(
        'Playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      // 外键 ON DELETE CASCADE 会自动删除 PlaylistSongs 中的关联记录
    } catch (e) {
      _logger.e('Failed to delete playlist: $e');
      rethrow;
    }
  }

  // --- PlaylistSongs 表操作 ---

  // 添加歌曲到播放列表
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await database;
    try {
      await db.insert(
        'PlaylistSongs',
        {
          'playlist_id': playlistId,
          'song_id': songId,
          'added_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      _logger.e('Failed to add song to playlist: $e');
      rethrow;
    }
  }

  // 从播放列表移除歌曲
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    try {
      await db.delete(
        'PlaylistSongs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
      );
    } catch (e) {
      _logger.e('Failed to remove song from playlist: $e');
      rethrow;
    }
  }

  // 查询播放列表中的歌曲
  Future<List<SongModel>> getSongsInPlaylist(int playlistId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT Songs.* 
        FROM Songs 
        JOIN PlaylistSongs ON Songs.id = PlaylistSongs.song_id 
        WHERE PlaylistSongs.playlist_id = ? 
        ORDER BY PlaylistSongs.added_at
      ''', [playlistId]);
      return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
    } catch (e) {
      _logger.e('Failed to get songs in playlist: $e');
      rethrow;
    }
  }

  // --- Settings 表操作 ---

  // 设置配置值（如主题颜色）
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    try {
      final settingsModel = SettingsModel(key: key, value: value);
      await db.insert(
        'Settings',
        settingsModel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Failed to set setting: $e');
      rethrow;
    }
  }

  // 获取配置值
  Future<String?> getSetting(String key) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (maps.isNotEmpty) {
        final settingsModel = SettingsModel.fromMap(maps[0]);
        return settingsModel.value;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get setting: $e');
      rethrow;
    }
  }

  // 删除配置
  Future<void> deleteSetting(String key) async {
    final db = await database;
    try {
      await db.delete(
        'Settings',
        where: 'key = ?',
        whereArgs: [key],
      );
    } catch (e) {
      _logger.e('Failed to delete setting: $e');
      rethrow;
    }
  }

  // 关闭数据库（通常在应用退出时调用）
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}