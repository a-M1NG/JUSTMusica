import 'song_model.dart';

class PlaylistModel {
  final int? id;
  final String name;
  final DateTime createdAt;
  final List<SongModel>? songs;

  PlaylistModel({
    this.id,
    required this.name,
    required this.createdAt,
    this.songs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      songs: null, // songs 需要通过关联表查询
    );
  }
}