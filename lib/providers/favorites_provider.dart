import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/favorite_entry.dart';
import '../data/database_service.dart';

class FavoritesProvider extends ChangeNotifier {
  List<FavoriteEntry> _entries = [];
  final Set<String> _pathSet = {};
  bool _loading = false;

  List<FavoriteEntry> get entries => _entries;
  bool get loading => _loading;
  int get count => _entries.length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _entries = await DatabaseService.getFavorites();
    _pathSet
      ..clear()
      ..addAll(_entries.map((e) => e.videoPath));
    _loading = false;
    notifyListeners();
  }

  bool isFavorite(String videoPath) => _pathSet.contains(videoPath);

  Future<void> addFavorite(String videoPath, String videoName, String folderName) async {
    if (_pathSet.contains(videoPath)) return;
    final entry = FavoriteEntry(
      videoPath: videoPath,
      videoName: videoName,
      folderName: folderName,
      addedAt: DateTime.now(),
    );
    await DatabaseService.addFavorite(entry);
    _entries.insert(0, entry);
    _pathSet.add(videoPath);
    notifyListeners();
  }

  Future<void> removeFavorite(String videoPath) async {
    if (!_pathSet.contains(videoPath)) return;
    await DatabaseService.removeFavorite(videoPath);
    _entries.removeWhere((e) => e.videoPath == videoPath);
    _pathSet.remove(videoPath);
    notifyListeners();
  }

  Future<void> toggleFavorite(
    String videoPath,
    String videoName,
    String folderName,
  ) async {
    if (isFavorite(videoPath)) {
      await removeFavorite(videoPath);
    } else {
      await addFavorite(videoPath, videoName, folderName);
    }
  }

  Future<void> clearAll() async {
    await DatabaseService.clearFavorites();
    _entries = [];
    _pathSet.clear();
    notifyListeners();
  }

  /// Remove entries whose files no longer exist on disk.
  Future<void> cleanMissingFiles() async {
    final missing = _entries
        .where((e) => !File(e.videoPath).existsSync())
        .map((e) => e.videoPath)
        .toList();
    for (final path in missing) {
      await DatabaseService.removeFavorite(path);
      _pathSet.remove(path);
    }
    _entries.removeWhere((e) => missing.contains(e.videoPath));
    if (missing.isNotEmpty) notifyListeners();
  }
}
