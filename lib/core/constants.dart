class AppConstants {
  static const String appName = 'VidéoLib';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'videolib.db';
  static const int dbVersion = 2;

  // Supported video extensions
  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    'm4v', 'mpg', 'mpeg', '3gp', 'ts', 'm2ts', 'mts',
    'vob', 'ogv', 'f4v', 'rmvb', 'rm', 'divx',
  ];

  // SharedPreferences keys
  static const String keyTheme = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyPlaybackMode = 'playback_mode';
  static const String keyAutoPlay = 'auto_play';
  static const String keyDefaultSpeed = 'default_speed';
  static const String keyAutoDeleteHistory = 'auto_delete_history';
  static const String keyLastHistoryClean = 'last_history_clean';
  static const String keySubtitleEnabled = 'subtitle_enabled';
  static const String keyBrightness = 'player_brightness';
  static const String keyVolume = 'player_volume';

  // Playback modes
  static const int playbackSingle = 0;
  static const int playbackNext = 1;
  static const int playbackLoop = 2;
  static const int playbackShuffle = 3;

  // Thumbnail cache
  static const int thumbnailQuality = 60;
  static const int thumbnailWidth = 320;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // Player overlay hide delay
  static const Duration playerOverlayDelay = Duration(seconds: 3);

  // Max history entries
  static const int maxHistoryEntries = 200;
}
