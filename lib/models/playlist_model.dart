import 'song_model.dart';

class PlaylistModel {
  final int? id;
  String name;
  final DateTime createdAt;
  final String? coverPath; // 新增 coverPath 字段
  final List<SongModel>? songs;

  PlaylistModel({
    this.id,
    required this.name,
    required this.createdAt,
    this.coverPath,
    this.songs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'cover_path': coverPath,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      coverPath: map['cover_path'],
      songs: null, // songs 需要通过关联表查询
    );
  }

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, coverPath: $coverPath, songs: ${songs?.length ?? 0})';
}
