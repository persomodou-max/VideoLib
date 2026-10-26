class HistoryEntry {
  final int? id;
  final String videoPath;
  final String videoName;
  final String folderName;
  final DateTime watchedAt;
  final Duration lastPosition;
  final Duration? totalDuration;

  HistoryEntry({
    this.id,
    required this.videoPath,
    required this.videoName,
    required this.folderName,
    required this.watchedAt,
    required this.lastPosition,
    this.totalDuration,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(watchedAt);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${watchedAt.day.toString().padLeft(2, '0')}/${watchedAt.month.toString().padLeft(2, '0')}/${watchedAt.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoPath': videoPath,
      'videoName': videoName,
      'folderName': folderName,
      'watchedAt': watchedAt.millisecondsSinceEpoch,
      'lastPositionMs': lastPosition.inMilliseconds,
      'totalDurationMs': totalDuration?.inMilliseconds,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'],
      videoPath: map['videoPath'],
      videoName: map['videoName'],
      folderName: map['folderName'] ?? '',
      watchedAt: DateTime.fromMillisecondsSinceEpoch(map['watchedAt']),
      lastPosition: Duration(milliseconds: map['lastPositionMs'] ?? 0),
      totalDuration: map['totalDurationMs'] != null
          ? Duration(milliseconds: map['totalDurationMs'])
          : null,
    );
  }

  HistoryEntry copyWith({Duration? lastPosition, DateTime? watchedAt}) {
    return HistoryEntry(
      id: id,
      videoPath: videoPath,
      videoName: videoName,
      folderName: folderName,
      watchedAt: watchedAt ?? this.watchedAt,
      lastPosition: lastPosition ?? this.lastPosition,
      totalDuration: totalDuration,
    );
  }
}
