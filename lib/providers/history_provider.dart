import 'package:flutter/foundation.dart';
import '../models/history_entry.dart';
import '../data/database_service.dart';
import '../core/constants.dart';

class HistoryProvider extends ChangeNotifier {
  List<HistoryEntry> _entries = [];
  bool _loading = false;

  List<HistoryEntry> get entries => _entries;
  bool get loading => _loading;
  int get count => _entries.length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _entries = await DatabaseService.getHistory(limit: AppConstants.maxHistoryEntries);
    _loading = false;
    notifyListeners();
  }

  Future<void> addOrUpdate(String path, String name, String folder, Duration position, Duration? total) async {
    final entry = HistoryEntry(
      videoPath: path,
      videoName: name,
      folderName: folder,
      watchedAt: DateTime.now(),
      lastPosition: position,
      totalDuration: total,
    );
    await DatabaseService.upsertEntry(entry);
    await DatabaseService.trimHistory(AppConstants.maxHistoryEntries);
    await load();
  }

  Future<Duration?> getLastPosition(String path) async {
    final entry = await DatabaseService.getEntryForPath(path);
    if (entry == null) return null;
    // Only resume if more than 5 seconds in and not at the end
    if (entry.lastPosition.inSeconds < 5) return null;
    if (entry.totalDuration != null) {
      final remaining = entry.totalDuration! - entry.lastPosition;
      if (remaining.inSeconds < 10) return null; // Video was near end
    }
    return entry.lastPosition;
  }

  Future<void> deleteEntry(int id) async {
    await DatabaseService.deleteEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await DatabaseService.clearHistory();
    _entries = [];
    notifyListeners();
  }

  Future<void> autoCleanIfNeeded() async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    await DatabaseService.deleteOlderThan(yesterday);
    await load();
  }
}
