import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Theme
  ThemeMode _themeMode = ThemeMode.dark;

  // Language
  Locale _locale = const Locale('fr');

  // Playback
  int _playbackMode = AppConstants.playbackNext;
  bool _autoPlay = true;
  double _defaultSpeed = 1.0;

  // History
  bool _autoDeleteHistory = false;

  // Subtitles
  bool _subtitleEnabled = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  int get playbackMode => _playbackMode;
  bool get autoPlay => _autoPlay;
  double get defaultSpeed => _defaultSpeed;
  bool get autoDeleteHistory => _autoDeleteHistory;
  bool get subtitleEnabled => _subtitleEnabled;
  bool get initialized => _initialized;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _initialized = true;
    notifyListeners();
    _checkAutoDeleteHistory();
  }

  void _loadFromPrefs() {
    final themeStr = _prefs.getString(AppConstants.keyTheme) ?? 'dark';
    _themeMode = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

    final langStr = _prefs.getString(AppConstants.keyLanguage) ?? 'fr';
    _locale = Locale(langStr);

    _playbackMode = _prefs.getInt(AppConstants.keyPlaybackMode) ?? AppConstants.playbackNext;
    _autoPlay = _prefs.getBool(AppConstants.keyAutoPlay) ?? true;
    _defaultSpeed = _prefs.getDouble(AppConstants.keyDefaultSpeed) ?? 1.0;
    _autoDeleteHistory = _prefs.getBool(AppConstants.keyAutoDeleteHistory) ?? false;
    _subtitleEnabled = _prefs.getBool(AppConstants.keySubtitleEnabled) ?? false;
  }

  void _checkAutoDeleteHistory() {
    if (!_autoDeleteHistory) return;
    final lastClean = _prefs.getInt(AppConstants.keyLastHistoryClean);
    final now = DateTime.now();
    if (lastClean == null) {
      _performHistoryClean(now);
      return;
    }
    final lastCleanDate = DateTime.fromMillisecondsSinceEpoch(lastClean);
    if (now.difference(lastCleanDate).inHours >= 24) {
      _performHistoryClean(now);
    }
  }

  Future<void> _performHistoryClean(DateTime now) async {
    // Delete entries older than 24h
    // (DatabaseService.deleteOlderThan will be called from HistoryProvider)
    await _prefs.setInt(
      AppConstants.keyLastHistoryClean,
      now.millisecondsSinceEpoch,
    );
  }

  // Setters
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(
      AppConstants.keyTheme,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _prefs.setString(AppConstants.keyLanguage, locale.languageCode);
    notifyListeners();
  }

  Future<void> setPlaybackMode(int mode) async {
    _playbackMode = mode;
    await _prefs.setInt(AppConstants.keyPlaybackMode, mode);
    notifyListeners();
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    await _prefs.setBool(AppConstants.keyAutoPlay, value);
    notifyListeners();
  }

  Future<void> setDefaultSpeed(double speed) async {
    _defaultSpeed = speed;
    await _prefs.setDouble(AppConstants.keyDefaultSpeed, speed);
    notifyListeners();
  }

  Future<void> setAutoDeleteHistory(bool value) async {
    _autoDeleteHistory = value;
    await _prefs.setBool(AppConstants.keyAutoDeleteHistory, value);
    notifyListeners();
  }

  Future<void> setSubtitleEnabled(bool value) async {
    _subtitleEnabled = value;
    await _prefs.setBool(AppConstants.keySubtitleEnabled, value);
    notifyListeners();
  }

  String get playbackModeLabel {
    switch (_playbackMode) {
      case AppConstants.playbackSingle:
        return 'Vidéo unique';
      case AppConstants.playbackNext:
        return 'Lecture suivante';
      case AppConstants.playbackLoop:
        return 'Boucle';
      case AppConstants.playbackShuffle:
        return 'Aléatoire';
      default:
        return 'Lecture suivante';
    }
  }
}
