import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/media_service.dart';

/// Lazy thumbnail widget — loads asynchronously and shows a shimmer while waiting.
/// Retries once on failure and keeps the image in memory via FutureBuilder caching.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = MediaService.getThumbnail(widget.videoPath);
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget old) {
    super.didUpdateWidget(old);
    if (old.videoPath != widget.videoPath) {
      _future = MediaService.getThumbnail(widget.videoPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState != ConnectionState.done) {
          return _Shimmer(width: widget.width, height: widget.height);
        }

        final data = snapshot.data;

        // Failed or empty
        if (data == null || data.isEmpty) {
          return _Placeholder(width: widget.width, height: widget.height);
        }

        // Success
        return Image.memory(
          data,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              _Placeholder(width: widget.width, height: widget.height),
        );
      },
    );
  }
}

// ─── Shimmer loading placeholder ─────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double? width;
  final double? height;
  const _Shimmer({this.width, this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF1A2235),
              Color.lerp(const Color(0xFF1A2235), const Color(0xFF243050), _anim.value)!,
              const Color(0xFF1A2235),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─── Error / no-thumb placeholder ────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final double? width;
  final double? height;
  const _Placeholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.darkCard,
      child: const Center(
        child: Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 28),
      ),
    );
  }
}
