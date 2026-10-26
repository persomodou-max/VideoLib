import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../models/history_entry.dart';
import '../models/favorite_entry.dart';

class DatabaseService {
  static Database? _db;
  static const _historyTable = 'history';
  static const _favoritesTable = 'favorites';

  // Keep old getter name for backward compatibility
  static const _table = _historyTable;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_historyTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoPath TEXT NOT NULL,
        videoName TEXT NOT NULL,
        folderName TEXT NOT NULL DEFAULT '',
        watchedAt INTEGER NOT NULL,
        lastPositionMs INTEGER NOT NULL DEFAULT 0,
        totalDurationMs INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_path ON $_historyTable(videoPath)');

    await db.execute('''
      CREATE TABLE $_favoritesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoPath TEXT NOT NULL UNIQUE,
        videoName TEXT NOT NULL,
        folderName TEXT NOT NULL DEFAULT '',
        addedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_fav_path ON $_favoritesTable(videoPath)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add favorites table for users upgrading from v1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_favoritesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          videoPath TEXT NOT NULL UNIQUE,
          videoName TEXT NOT NULL,
          folderName TEXT NOT NULL DEFAULT '',
          addedAt INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fav_path ON $_favoritesTable(videoPath)',
      );
    }
  }

  // ---- Favorites CRUD ----

  static Future<List<FavoriteEntry>> getFavorites() async {
    final db = await database;
    final maps = await db.query(_favoritesTable, orderBy: 'addedAt DESC');
    return maps.map(FavoriteEntry.fromMap).toList();
  }

  static Future<bool> isFavorite(String videoPath) async {
    final db = await database;
    final maps = await db.query(
      _favoritesTable,
      where: 'videoPath = ?',
      whereArgs: [videoPath],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  static Future<void> addFavorite(FavoriteEntry entry) async {
    final db = await database;
    await db.insert(
      _favoritesTable,
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeFavorite(String videoPath) async {
    final db = await database;
    await db.delete(
      _favoritesTable,
      where: 'videoPath = ?',
      whereArgs: [videoPath],
    );
  }

  static Future<void> clearFavorites() async {
    final db = await database;
    await db.delete(_favoritesTable);
  }

  // ---- History CRUD ----

  static Future<List<HistoryEntry>> getHistory({int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      _table,
      orderBy: 'watchedAt DESC',
      limit: limit,
    );
    return maps.map(HistoryEntry.fromMap).toList();
  }

  static Future<HistoryEntry?> getEntryForPath(String path) async {
    final db = await database;
    final maps = await db.query(
      _table,
      where: 'videoPath = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HistoryEntry.fromMap(maps.first);
  }

  static Future<void> upsertEntry(HistoryEntry entry) async {
    final db = await database;
    final count = await db.update(
      _table,
      {
        'videoName': entry.videoName,
        'folderName': entry.folderName,
        'watchedAt': entry.watchedAt.millisecondsSinceEpoch,
        'lastPositionMs': entry.lastPosition.inMilliseconds,
        'totalDurationMs': entry.totalDuration?.inMilliseconds,
      },
      where: 'videoPath = ?',
      whereArgs: [entry.videoPath],
    );
    if (count == 0) {
      await db.insert(_table, entry.toMap()..remove('id'));
    }
  }

  static Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearHistory() async {
    final db = await database;
    await db.delete(_table);
  }

  static Future<void> deleteOlderThan(DateTime date) async {
    final db = await database;
    await db.delete(
      _table,
      where: 'watchedAt < ?',
      whereArgs: [date.millisecondsSinceEpoch],
    );
  }

  static Future<int> getHistoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Trim history to max entries
  static Future<void> trimHistory(int maxEntries) async {
    final db = await database;
    await db.execute('''
      DELETE FROM $_table WHERE id NOT IN (
        SELECT id FROM $_table ORDER BY watchedAt DESC LIMIT $maxEntries
      )
    ''');
  }
}
