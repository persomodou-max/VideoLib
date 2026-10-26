import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/theme.dart';
import '../models/video_file.dart';
import '../data/media_service.dart';

enum SortMode { name, date, duration, size }

class LibraryProvider extends ChangeNotifier {
  List<VideoFile> _allVideos = [];
  List<VideoFile> _filteredVideos = [];
  Map<String, VideoFolder> _folders = {};
  bool _loading = false;
  bool _initialized = false;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.name;
  bool _sortAscending = true;
  String? _currentFolderPath;

  // Getters
  List<VideoFile> get allVideos => _filteredVideos;
  List<VideoFile> get rawAllVideos => _allVideos;
  Map<String, VideoFolder> get folders => _folders;
  bool get loading => _loading;
  bool get initialized => _initialized;
  SortMode get sortMode => _sortMode;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery;
  String? get currentFolderPath => _currentFolderPath;

  List<VideoFolder> get sortedFolders {
    final list = _folders.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<VideoFile> get currentFolderVideos {
    if (_currentFolderPath == null) return [];
    return _folders[_currentFolderPath]?.videos ?? [];
  }

  int get totalVideoCount => _allVideos.length;
  int get folderCount => _folders.length;

  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final roots = MediaService.getStorageRoots();
      _allVideos = await MediaService.scanAllVideos(roots);
      _buildFolders();
      _applyFiltersAndSort();
    } catch (e) {
      debugPrint('Library refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _buildFolders() {
    final grouped = MediaService.groupByFolder(_allVideos);
    final newFolders = <String, VideoFolder>{};
    int colorIdx = 0;
    for (final entry in grouped.entries) {
      final folderName = entry.key.split(Platform.pathSeparator).last;
      newFolders[entry.key] = VideoFolder(
        path: entry.key,
        name: folderName,
        videos: entry.value,
        colorIndex: colorIdx % AppColors.folderColors.length,
      );
      colorIdx++;
    }
    _folders = newFolders;
  }

  void _applyFiltersAndSort() {
    var list = List<VideoFile>.from(_allVideos);

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) => v.name.toLowerCase().contains(q)).toList();
    }

    // Sort
    list.sort((a, b) {
      int cmp;
      switch (_sortMode) {
        case SortMode.name:
          cmp = a.nameWithoutExtension.toLowerCase().compareTo(b.nameWithoutExtension.toLowerCase());
          break;
        case SortMode.date:
          cmp = a.lastModified.compareTo(b.lastModified);
          break;
        case SortMode.duration:
          cmp = (a.duration?.inSeconds ?? 0).compareTo(b.duration?.inSeconds ?? 0);
          break;
        case SortMode.size:
          cmp = a.size.compareTo(b.size);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    _filteredVideos = list;
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    if (_sortMode == mode) {
      _sortAscending = !_sortAscending;
    } else {
      _sortMode = mode;
      _sortAscending = true;
    }
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setCurrentFolder(String? path) {
    _currentFolderPath = path;
    notifyListeners();
  }

  List<VideoFile> searchVideos(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _allVideos.where((v) => v.name.toLowerCase().contains(q)).toList();
  }

  Future<bool> deleteVideo(VideoFile video) async {
    try {
      final file = File(video.path);
      if (file.existsSync()) {
        await file.delete();
        _allVideos.removeWhere((v) => v.path == video.path);
        _buildFolders();
        _applyFiltersAndSort();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }
    return false;
  }

  Future<bool> renameVideo(VideoFile video, String newName) async {
    try {
      final file = File(video.path);
      final dir = video.folderPath;
      final ext = video.extension;
      final newPath = '$dir${Platform.pathSeparator}$newName.$ext';
      await file.rename(newPath);
      await refresh();
      return true;
    } catch (e) {
      debugPrint('Rename error: $e');
      return false;
    }
  }

  Future<bool> moveVideo(VideoFile video, String targetFolder) async {
    try {
      final file = File(video.path);
      final newPath = '$targetFolder${Platform.pathSeparator}${video.name}';
      await file.rename(newPath);
      await refresh();
      return true;
    } catch (e) {
      debugPrint('Move error: $e');
      return false;
    }
  }

  Future<bool> copyVideo(VideoFile video, String targetFolder) async {
    try {
      final file = File(video.path);
      final newPath = '$targetFolder${Platform.pathSeparator}${video.name}';
      await file.copy(newPath);
      await refresh();
      return true;
    } catch (e) {
      debugPrint('Copy error: $e');
      return false;
    }
  }

  // Get next/previous video in folder
  VideoFile? getNextVideo(VideoFile current, {bool shuffle = false}) {
    final folder = _folders[current.folderPath];
    if (folder == null || folder.videos.isEmpty) return null;
    final videos = folder.videos;
    if (shuffle) {
      final others = videos.where((v) => v.path != current.path).toList();
      if (others.isEmpty) return null;
      others.shuffle();
      return others.first;
    }
    final idx = videos.indexWhere((v) => v.path == current.path);
    if (idx < 0 || idx >= videos.length - 1) return null;
    return videos[idx + 1];
  }

  VideoFile? getPreviousVideo(VideoFile current) {
    final folder = _folders[current.folderPath];
    if (folder == null) return null;
    final videos = folder.videos;
    final idx = videos.indexWhere((v) => v.path == current.path);
    if (idx <= 0) return null;
    return videos[idx - 1];
  }
}


