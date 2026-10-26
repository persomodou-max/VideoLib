import 'dart:io';
import 'package:flutter/foundation.dart';

class VideoFile {
  final String path;
  final String name;
  final String nameWithoutExtension;
  final String extension;
  final int size;
  final DateTime lastModified;
  final Duration? duration;
  Uint8List? thumbnail;
  bool thumbnailLoaded;

  VideoFile({
    required this.path,
    required this.name,
    required this.nameWithoutExtension,
    required this.extension,
    required this.size,
    required this.lastModified,
    this.duration,
    this.thumbnail,
    this.thumbnailLoaded = false,
  });

  factory VideoFile.fromFile(File file, {Duration? duration}) {
    final name = file.path.split(Platform.pathSeparator).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final nameNoExt = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;

    return VideoFile(
      path: file.path,
      name: name,
      nameWithoutExtension: nameNoExt,
      extension: ext,
      size: file.existsSync() ? file.lengthSync() : 0,
      lastModified: file.existsSync() ? file.lastModifiedSync() : DateTime.now(),
      duration: duration,
    );
  }

  String get formattedSize {
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} Ko';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
    }
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60);
    final s = duration!.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}min';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get folderPath {
    final parts = path.split(Platform.pathSeparator);
    parts.removeLast();
    return parts.join(Platform.pathSeparator);
  }

  String get folderName {
    return folderPath.split(Platform.pathSeparator).last;
  }

  VideoFile copyWith({Duration? duration, Uint8List? thumbnail, bool? thumbnailLoaded}) {
    return VideoFile(
      path: path,
      name: name,
      nameWithoutExtension: nameWithoutExtension,
      extension: extension,
      size: size,
      lastModified: lastModified,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      thumbnailLoaded: thumbnailLoaded ?? this.thumbnailLoaded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'durationMs': duration?.inMilliseconds,
    };
  }

  @override
  bool operator ==(Object other) => other is VideoFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class VideoFolder {
  final String path;
  final String name;
  final List<VideoFile> videos;
  final int colorIndex;

  VideoFolder({
    required this.path,
    required this.name,
    required this.videos,
    this.colorIndex = 0,
  });

  int get videoCount => videos.length;

  String get countLabel => '$videoCount vidéo${videoCount > 1 ? 's' : ''}';
}
