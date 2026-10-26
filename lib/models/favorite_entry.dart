/// Represents a video file that has been marked as a favorite.
class FavoriteEntry {
  final int? id;
  final String videoPath;
  final String videoName;
  final String folderName;
  final DateTime addedAt;

  const FavoriteEntry({
    this.id,
    required this.videoPath,
    required this.videoName,
    required this.folderName,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'videoPath': videoPath,
        'videoName': videoName,
        'folderName': folderName,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  factory FavoriteEntry.fromMap(Map<String, dynamic> map) => FavoriteEntry(
        id: map['id'] as int?,
        videoPath: map['videoPath'] as String,
        videoName: map['videoName'] as String,
        folderName: map['folderName'] as String,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      );

  FavoriteEntry copyWith({
    int? id,
    String? videoPath,
    String? videoName,
    String? folderName,
    DateTime? addedAt,
  }) =>
      FavoriteEntry(
        id: id ?? this.id,
        videoPath: videoPath ?? this.videoPath,
        videoName: videoName ?? this.videoName,
        folderName: folderName ?? this.folderName,
        addedAt: addedAt ?? this.addedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is FavoriteEntry && other.videoPath == videoPath;

  @override
  int get hashCode => videoPath.hashCode;
}
