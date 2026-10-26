import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../models/video_file.dart';

class _ThumbRequest {
  final String path;
  final Completer<Uint8List?> completer = Completer();
  _ThumbRequest(this.path);
}

class MediaService {
  static final LinkedHashMap<String, Uint8List?> _memoryCache =
      LinkedHashMap<String, Uint8List?>();
  static const int _maxCacheSize = 60;

  static const _thumbChannel = MethodChannel('videolib/thumbnail');

  // ─── Directory scanning ───────────────────────────────────────────────────

  static Future<List<VideoFile>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final videos = <VideoFile>[];
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
          if (AppConstants.videoExtensions.contains(ext)) {
            videos.add(VideoFile.fromFile(entity));
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning $dirPath: $e');
    }
    return videos;
  }

  static Future<List<VideoFile>> scanAllVideos(List<String> roots) async {
    final videos = <VideoFile>[];
    final seen = <String>{};
    for (final root in roots) {
      await _scanRecursive(Directory(root), videos, seen, 0);
    }
    return videos;
  }

  static final Set<String> _ignoredDirs = {
    'Android', 'Lost+Found', '.thumbnails', 'thumbnails', 'cache',
    'node_modules', '.git', 'System Volume Information', r'$Recycle.Bin',
  };

  static Future<void> _scanRecursive(
    Directory dir,
    List<VideoFile> results,
    Set<String> seen,
    int depth,
  ) async {
    if (depth > 8) return;
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
          if (AppConstants.videoExtensions.contains(ext) &&
              !seen.contains(entity.path)) {
            seen.add(entity.path);
            results.add(VideoFile.fromFile(entity));
          }
        } else if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.') && !_ignoredDirs.contains(name)) {
            await _scanRecursive(entity, results, seen, depth + 1);
          }
        }
      }
    } catch (_) {}
  }

  static Map<String, List<VideoFile>> groupByFolder(List<VideoFile> videos) {
    final map = <String, List<VideoFile>>{};
    for (final video in videos) {
      map.putIfAbsent(video.folderPath, () => []).add(video);
    }
    return map;
  }

  // ─── Thumbnail via native MediaMetadataRetriever ──────────────────────────

  // Allow up to 3 concurrent thumbnail requests
  static int _activeRequests = 0;
  static const int _maxConcurrent = 3;
  static final List<_ThumbRequest> _pendingQueue = [];

  static Future<Uint8List?> getThumbnail(String videoPath) async {
    // 1. Memory cache (LRU)
    if (_memoryCache.containsKey(videoPath)) {
      final hit = _memoryCache.remove(videoPath);
      _memoryCache[videoPath] = hit;
      return hit;
    }

    // 2. Disk cache
    final diskHit = await _readDiskCache(videoPath);
    if (diskHit != null) {
      _addToMemoryCache(videoPath, diskHit);
      return diskHit;
    }

    // 3. Non-Android: not supported
    if (!Platform.isAndroid) {
      _addToMemoryCache(videoPath, null);
      return null;
    }

    // 4. Throttle concurrent requests
    return _enqueue(videoPath);
  }

  static Future<Uint8List?> _enqueue(String videoPath) async {
    final req = _ThumbRequest(videoPath);
    _pendingQueue.add(req);
    _drainQueue();
    return req.completer.future;
  }

  static void _drainQueue() {
    while (_activeRequests < _maxConcurrent && _pendingQueue.isNotEmpty) {
      final req = _pendingQueue.removeAt(0);
      _activeRequests++;
      _fetchNative(req.path).then((bytes) {
        req.completer.complete(bytes);
      }).catchError((e) {
        req.completer.complete(null);
      }).whenComplete(() {
        _activeRequests--;
        _drainQueue();
      });
    }
  }

  static Future<Uint8List?> _fetchNative(String videoPath) async {
    try {
      final result = await _thumbChannel.invokeMethod<Uint8List>(
        'getThumbnail',
        {
          'path': videoPath,
          'timeUs': 5000000,
          'maxWidth': AppConstants.thumbnailWidth,
          'quality': AppConstants.thumbnailQuality,
        },
      );

      if (result != null && result.isNotEmpty) {
        await _writeDiskCache(videoPath, result);
        _addToMemoryCache(videoPath, result);
        return result;
      }
    } on PlatformException catch (e) {
      debugPrint('Thumbnail channel error for $videoPath: ${e.message}');
    } catch (e) {
      debugPrint('Thumbnail error for $videoPath: $e');
    }

    _addToMemoryCache(videoPath, null);
    return null;
  }

  // ─── Cache helpers ────────────────────────────────────────────────────────

  static void _addToMemoryCache(String key, Uint8List? data) {
    _memoryCache.remove(key);
    if (_memoryCache.length >= _maxCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = data;
  }

  static String _cacheKey(String videoPath) =>
      (videoPath.hashCode ^ (videoPath.length * 31)).abs().toString();

  static Future<Uint8List?> _readDiskCache(String videoPath) async {
    try {
      final cacheDir = await _getCacheDir();
      final key = _cacheKey(videoPath);
      // Check .jpg (current) then .png (legacy)
      for (final ext in ['.jpg', '.png']) {
        final file = File(p.join(cacheDir, '$key$ext'));
        if (file.existsSync()) return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeDiskCache(String videoPath, Uint8List data) async {
    try {
      final cacheDir = await _getCacheDir();
      final key = _cacheKey(videoPath);
      final file = File(p.join(cacheDir, '$key.jpg'));
      await file.writeAsBytes(data);
    } catch (_) {}
  }

  static Future<String> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'videolib_thumbs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Future<void> clearThumbnailCache() async {
    _memoryCache.clear();
    final cacheDir = await _getCacheDir();
    final dir = Directory(cacheDir);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  // ─── Storage roots ────────────────────────────────────────────────────────

  static List<String> getStorageRoots() {
    final roots = <String>[];
    if (Platform.isAndroid) {
      roots.add('/storage/emulated/0');
      for (final path in ['/storage/sdcard1', '/storage/extSdCard']) {
        if (Directory(path).existsSync()) roots.add(path);
      }
    } else if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        for (final sub in ['Videos', 'Downloads', 'Desktop']) {
          final path = '$home\\$sub';
          if (Directory(path).existsSync()) roots.add(path);
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        for (final sub in ['Videos', 'Movies', 'Downloads']) {
          final path = '$home/$sub';
          if (Directory(path).existsSync()) roots.add(path);
        }
      }
    }
    return roots;
  }
}
