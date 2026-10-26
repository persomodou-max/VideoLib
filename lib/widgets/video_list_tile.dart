import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/video_file.dart';
import 'video_thumbnail_widget.dart';

class VideoListTile extends StatelessWidget {
  final VideoFile video;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumbnailWidget(videoPath: video.path, fit: BoxFit.cover),
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: Colors.white,
                        size: 26,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.nameWithoutExtension,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (video.duration != null) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(video.formattedDuration, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 10),
                      ],
                      Icon(Icons.storage_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(video.formattedSize, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
