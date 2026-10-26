import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/settings_provider.dart';
import '../providers/history_provider.dart';
import '../providers/favorites_provider.dart';

class PlayerScreen extends StatefulWidget {
  final String videoPath;
  final List<String> videoList;
  final int startIndex;

  const PlayerScreen({
    super.key,
    required this.videoPath,
    required this.videoList,
    required this.startIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullscreen = false;
  bool _isDragging = false;
  bool _isLocked = false; // screen lock mode

  // Brightness & volume slider visibility
  bool _showBrightnessSlider = false;
  bool _showVolumeSlider = false;
  Timer? _sliderHideTimer;

  // Current track info
  late int _currentIndex;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  double _brightness = 0.5;
  BoxFit _videoFit = BoxFit.contain;

  // Playback mode (from settings, overridable per session)
  late int _playbackMode;

  final _subscriptions = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.startIndex;

    _player = Player();
    _controller = VideoController(_player);

    final settings = context.read<SettingsProvider>();
    _playbackMode = settings.playbackMode;
    _playbackSpeed = settings.defaultSpeed;
    _volume = 1.0;

    _initBrightness();
    _setupSubscriptions();
    _openVideo();
    _resetHideTimer();
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().application;
    } catch (_) {
      _brightness = 0.5;
    }
  }

  void _setupSubscriptions() {
    _subscriptions.addAll([
      _player.stream.position.listen((pos) {
        if (!_isDragging) setState(() => _position = pos);
        // Save position to history every 5 seconds while playing
        if (_isPlaying && !_isDragging && pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
          _saveHistory(pos);
        }
      }),
      _player.stream.duration.listen((dur) => setState(() => _duration = dur)),
      _player.stream.playing.listen((playing) => setState(() => _isPlaying = playing)),
      _player.stream.buffering.listen((buf) => setState(() => _isBuffering = buf)),
      _player.stream.completed.listen((completed) {
        if (completed) _handleVideoEnd();
      }),
      _player.stream.volume.listen((v) => setState(() => _volume = v / 100)),
    ]);
  }

  Future<void> _openVideo() async {
    final path = widget.videoList.isNotEmpty
        ? widget.videoList[_currentIndex]
        : widget.videoPath;

    // Check for resume position
    final history = context.read<HistoryProvider>();
    final resumePos = await history.getLastPosition(path);

    await _player.open(Media(path));
    await _player.setRate(_playbackSpeed);

    if (resumePos != null && resumePos.inSeconds > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _player.seek(resumePos);
    }
  }

  Future<void> _saveHistory(Duration position) async {
    if (!mounted) return;
    final path = widget.videoList.isNotEmpty
        ? widget.videoList[_currentIndex]
        : widget.videoPath;
    final name = path.split(Platform.pathSeparator).last;
    final parts = path.split(Platform.pathSeparator);
    final folderName = parts.length >= 2 ? parts[parts.length - 2] : '';

    final historyProvider = context.read<HistoryProvider>();
    await historyProvider.addOrUpdate(
      path, name, folderName, position, _duration,
    );
  }

  void _handleVideoEnd() {
    switch (_playbackMode) {
      case AppConstants.playbackSingle:
        break;
      case AppConstants.playbackLoop:
        _player.seek(Duration.zero);
        _player.play();
        break;
      case AppConstants.playbackNext:
        _playNext();
        break;
      case AppConstants.playbackShuffle:
        _playShuffle();
        break;
    }
  }

  void _playNext() {
    if (widget.videoList.isEmpty) return;
    final nextIdx = _currentIndex + 1;
    if (nextIdx < widget.videoList.length) {
      setState(() => _currentIndex = nextIdx);
      _openVideo();
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex = _currentIndex - 1);
      _openVideo();
    } else {
      _player.seek(Duration.zero);
    }
  }

  void _playShuffle() {
    if (widget.videoList.length <= 1) return;
    int nextIdx;
    final rng = Random();
    do {
      nextIdx = rng.nextInt(widget.videoList.length);
    } while (nextIdx == _currentIndex && widget.videoList.length > 1);
    setState(() => _currentIndex = nextIdx);
    _openVideo();
  }

  void _toggleControls() {
    if (_isLocked) {
      // In locked mode, show only the unlock button briefly
      setState(() => _showControls = !_showControls);
      if (_showControls) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showControls = false);
        });
      }
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppConstants.playerOverlayDelay, () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  static const MethodChannel _pipChannel = MethodChannel('videolib/pip');

  Future<void> _togglePiP() async {
    try {
      await _pipChannel.invokeMethod('enterPiP');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mode PiP non disponible sur cet appareil')),
        );
      }
    }
  }

  void _setBrightness(double value) async {
    setState(() => _brightness = value);
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  void _showBrightnessControl() {
    setState(() {
      _showBrightnessSlider = true;
      _showVolumeSlider = false;
    });
    _startSliderHideTimer();
  }

  void _showVolumeControl() {
    setState(() {
      _showVolumeSlider = true;
      _showBrightnessSlider = false;
    });
    _startSliderHideTimer();
  }

  void _startSliderHideTimer() {
    _sliderHideTimer?.cancel();
    _sliderHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showBrightnessSlider = false;
          _showVolumeSlider = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveHistory(_position);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sliderHideTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _saveHistory(_position);
    _player.dispose();
    // Restore brightness
    ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get _currentVideoPath {
    if (widget.videoList.isEmpty) return widget.videoPath;
    return widget.videoList[_currentIndex];
  }

  String get _currentVideoName {
    return _currentVideoPath.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return _buildFullPlayer();
  }


  Widget _buildFullPlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          // Horizontal drag → seek, vertical drag left → brightness, right → volume
          onVerticalDragUpdate: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final x = details.globalPosition.dx;
            final delta = -details.delta.dy / 200; // normalize

            if (x < screenWidth / 2) {
              // Left side → brightness
              final newVal = (_brightness + delta).clamp(0.0, 1.0);
              _setBrightness(newVal);
              _showBrightnessControl();
            } else {
              // Right side → volume
              final newVol = (_volume + delta).clamp(0.0, 1.0);
              setState(() => _volume = newVol);
              _player.setVolume(newVol * 100);
              _showVolumeControl();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              Video(controller: _controller, fit: _videoFit),

              // Buffering indicator
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue),
                ),

              // Brightness / Volume side sliders
              if (_showBrightnessSlider)
                _buildSideSlider(
                  icon: Icons.brightness_6_rounded,
                  value: _brightness,
                  alignment: Alignment.centerLeft,
                ),
              if (_showVolumeSlider)
                _buildSideSlider(
                  icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  value: _volume,
                  alignment: Alignment.centerRight,
                ),

              // Lock overlay (when locked, show only unlock button)
              if (_isLocked)
                _buildLockOverlay()
              else
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: AppConstants.animNormal,
                  child: _buildControlsOverlay(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideSlider({
    required IconData icon,
    required double value,
    required AlignmentGeometry alignment,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Positioned(
      left: isLeft ? 16 : null,
      right: isLeft ? null : 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: AppConstants.animNormal,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () {
              setState(() => _isLocked = false);
              _resetHideTimer();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(context),
        ),

        // Center controls
        Center(child: _buildCenterControls()),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(context),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isFav = context.watch<FavoritesProvider>().isFavorite(_currentVideoPath);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentVideoName.replaceAll(RegExp(r'\.\w+$'), ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_duration.inSeconds > 0)
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Favorite toggle
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            onPressed: () {
              final parts = _currentVideoPath.split(Platform.pathSeparator);
              final folderName = parts.length >= 2 ? parts[parts.length - 2] : '';
              context.read<FavoritesProvider>().toggleFavorite(
                    _currentVideoPath,
                    _currentVideoName,
                    folderName,
                  );
            },
          ),

          // PiP button
          IconButton(
            icon: const Icon(Icons.picture_in_picture_rounded, color: Colors.white),
            onPressed: _togglePiP,
          ),

          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: _handleMenuOption,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'speed', child: Text('Vitesse de lecture')),
              PopupMenuItem(value: 'mode', child: Text('Mode de lecture')),
              PopupMenuItem(value: 'audio', child: Text('Pistes audio')),
              PopupMenuItem(value: 'subtitle', child: Text('Sous-titres')),
              PopupMenuItem(value: 'fit', child: Text('Format d\'affichage')),
              PopupMenuItem(value: 'info', child: Text('Informations')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        if (widget.videoList.length > 1)
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: 36,
            onTap: _playPrevious,
          ),
        const SizedBox(width: 12),

        // Rewind 10s
        _ControlButton(
          icon: Icons.replay_10_rounded,
          size: 40,
          onTap: () => _player.seek(_position - const Duration(seconds: 10)),
        ),
        const SizedBox(width: 20),

        // Play/Pause
        GestureDetector(
          onTap: () {
            _player.playOrPause();
            _resetHideTimer();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Forward 10s
        _ControlButton(
          icon: Icons.forward_10_rounded,
          size: 40,
          onTap: () => _player.seek(_position + const Duration(seconds: 10)),
        ),
        const SizedBox(width: 12),

        // Next
        if (widget.videoList.length > 1)
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 36,
            onTap: _playNext,
          ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress slider
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accentBlue,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChangeStart: (_) {
                      _isDragging = true;
                      _hideTimer?.cancel();
                    },
                    onChanged: (v) {
                      setState(() {
                        _position = Duration(
                          milliseconds: (v * _duration.inMilliseconds).round(),
                        );
                      });
                    },
                    onChangeEnd: (v) {
                      _isDragging = false;
                      _player.seek(Duration(
                        milliseconds: (v * _duration.inMilliseconds).round(),
                      ));
                      _resetHideTimer();
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          // Bottom action row
          Row(
            children: [
              // Lock screen
              _SmallControlButton(
                icon: _isLocked ? Icons.lock_rounded : Icons.lock_outline_rounded,
                onTap: () {
                  setState(() {
                    _isLocked = !_isLocked;
                    _showControls = false;
                  });
                },
              ),
              const SizedBox(width: 8),

              // Brightness
              _SmallControlButton(
                icon: Icons.brightness_6_rounded,
                onTap: _showBrightnessControl,
              ),
              const SizedBox(width: 8),

              // Speed
              GestureDetector(
                onTap: () => _showSpeedSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '$_playbackSpeed×',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const Spacer(),

              // Volume
              _SmallControlButton(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                  _player.setVolume(_isMuted ? 0 : _volume * 100);
                },
              ),
              const SizedBox(width: 8),

              // Playback mode
              _SmallControlButton(
                icon: _playbackModeIcon,
                onTap: _cyclePlaybackMode,
              ),
              const SizedBox(width: 8),

              // Fullscreen
              _SmallControlButton(
                icon: _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                onTap: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _playbackModeIcon {
    switch (_playbackMode) {
      case AppConstants.playbackLoop:
        return Icons.repeat_one_rounded;
      case AppConstants.playbackShuffle:
        return Icons.shuffle_rounded;
      case AppConstants.playbackSingle:
        return Icons.stop_circle_outlined;
      default:
        return Icons.repeat_rounded;
    }
  }

  void _cyclePlaybackMode() {
    setState(() {
      _playbackMode = (_playbackMode + 1) % 4;
    });
    context.read<SettingsProvider>().setPlaybackMode(_playbackMode);
    _showPlaybackModeSnackbar();
  }

  void _showPlaybackModeSnackbar() {
    final labels = ['Vidéo unique', 'Lecture suivante', 'Boucle', 'Aléatoire'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(labels[_playbackMode]),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleMenuOption(String option) {
    switch (option) {
      case 'speed':
        _showSpeedSheet(context);
        break;
      case 'mode':
        _showPlaybackModeSheet(context);
        break;
      case 'audio':
        _showAudioOptions(context);
        break;
      case 'subtitle':
        _showSubtitleOptions(context);
        break;
      case 'fit':
        _showFitOptions(context);
        break;
      case 'info':
        _showVideoInfo(context);
        break;
    }
  }

  void _showSpeedSheet(BuildContext context) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vitesse', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: speeds.map((s) {
                final isSelected = _playbackSpeed == s;
                return ChoiceChip(
                  label: Text('$s×'),
                  selected: isSelected,
                  selectedColor: AppColors.accentBlue,
                  onSelected: (_) async {
                    setState(() => _playbackSpeed = s);
                    await _player.setRate(s);
                    if (mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPlaybackModeSheet(BuildContext context) {
    final modes = [
      (AppConstants.playbackSingle, 'Vidéo unique', Icons.stop_circle_rounded),
      (AppConstants.playbackNext, 'Lecture suivante', Icons.skip_next_rounded),
      (AppConstants.playbackLoop, 'Boucle', Icons.repeat_one_rounded),
      (AppConstants.playbackShuffle, 'Aléatoire', Icons.shuffle_rounded),
    ];

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mode de lecture', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...modes.map((m) => ListTile(
                  leading: Icon(m.$3),
                  title: Text(m.$2),
                  trailing: _playbackMode == m.$1
                      ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                      : null,
                  selected: _playbackMode == m.$1,
                  selectedColor: AppColors.accentBlue,
                  onTap: () {
                    setState(() => _playbackMode = m.$1);
                    context.read<SettingsProvider>().setPlaybackMode(m.$1);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAudioOptions(BuildContext context) {
    final audioTracks = _player.state.tracks.audio;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pistes audio', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Par defaut'),
              trailing: _player.state.track.audio == AudioTrack.auto() ||
                      _player.state.track.audio == AudioTrack.no()
                  ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                  : null,
              onTap: () {
                _player.setAudioTrack(AudioTrack.auto());
                Navigator.pop(ctx);
              },
            ),
            ...audioTracks
                .where((t) => t != AudioTrack.no() && t != AudioTrack.auto())
                .map((track) => ListTile(
                      title: Text(
                        track.title ?? track.language ?? 'Piste ${audioTracks.indexOf(track)}',
                      ),
                      trailing: _player.state.track.audio == track
                          ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                          : null,
                      onTap: () {
                        _player.setAudioTrack(track);
                        Navigator.pop(ctx);
                      },
                    )),
            if (audioTracks
                .where((t) => t != AudioTrack.no() && t != AudioTrack.auto())
                .isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune piste audio disponible', style: TextStyle(color: AppColors.textMuted)),
              ),
          ],
        ),
      ),
    );
  }

  void _showFitOptions(BuildContext context) {
    final options = [
      (BoxFit.contain, 'Adapter (contain)', Icons.fit_screen_rounded),
      (BoxFit.cover, 'Remplir (cover)', Icons.crop_rounded),
      (BoxFit.fill, 'Etirer (fill)', Icons.fullscreen_rounded),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format d affichage', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
                  leading: Icon(o.$3),
                  title: Text(o.$2),
                  trailing: _videoFit == o.$1
                      ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                      : null,
                  onTap: () {
                    setState(() => _videoFit = o.$1);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSubtitleOptions(BuildContext context) {
    final subtitleTracks = _player.state.tracks.subtitle;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sous-titres', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Désactivés'),
              trailing: _player.state.track.subtitle == SubtitleTrack.no()
                  ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                  : null,
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(ctx);
              },
            ),
            ...subtitleTracks
                .where((t) => t != SubtitleTrack.no() && t != SubtitleTrack.auto())
                .map((track) => ListTile(
                      title: Text(
                        track.title ??
                            track.language ??
                            'Piste ${subtitleTracks.indexOf(track)}',
                      ),
                      trailing: _player.state.track.subtitle == track
                          ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                          : null,
                      onTap: () {
                        _player.setSubtitleTrack(track);
                        Navigator.pop(ctx);
                      },
                    )),
            if (subtitleTracks
                .where((t) => t != SubtitleTrack.no() && t != SubtitleTrack.auto())
                .isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucune piste de sous-titres disponible',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showVideoInfo(BuildContext context) {
    final path = _currentVideoPath;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Informations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Fichier', value: path.split(Platform.pathSeparator).last),
            _InfoRow(label: 'Durée', value: _formatDuration(_duration)),
            _InfoRow(label: 'Position', value: _formatDuration(_position)),
            _InfoRow(label: 'Vitesse', value: '$_playbackSpeed×'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

// ---- Helper widgets ----

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class _SmallControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12), softWrap: true),
          ),
        ],
      ),
    );
  }
}
