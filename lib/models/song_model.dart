class SongModel {
  final int? id;
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  final String? coverPath;
  bool isFavorite;

  SongModel({
    this.id,
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.coverPath,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'cover_path': coverPath,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'],
      path: map['path'],
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      duration: map['duration'],
      coverPath: map['cover_path'],
      isFavorite: map['is_favorite'] == 1,
    );
  }
}
