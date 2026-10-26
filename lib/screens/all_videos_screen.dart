import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../models/video_file.dart';
import '../widgets/video_list_tile.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../widgets/sort_bar.dart';

class AllVideosScreen extends StatefulWidget {
  const AllVideosScreen({super.key});

  @override
  State<AllVideosScreen> createState() => _AllVideosScreenState();
}

class _AllVideosScreenState extends State<AllVideosScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final videos = library.allVideos;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Toutes les vidéos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              '${videos.length} vidéo${videos.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: library.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            onPressed: () => library.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SortBar(
              current: library.sortMode,
              ascending: library.sortAscending,
              onSort: library.setSortMode,
            ),
          ),
          Expanded(
            child: videos.isEmpty && library.loading
                ? const Center(child: CircularProgressIndicator())
                : videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library_outlined, size: 60, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('Aucune vidéo trouvée'),
                          ],
                        ),
                      )
                    : _isGridView
                        ? _buildGrid(context, videos)
                        : _buildList(context, videos),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<VideoFile> videos) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: videos.length,
      itemBuilder: (context, index) => VideoListTile(
        video: videos[index],
        onTap: () => context.push('/player', extra: {
          'path': videos[index].path,
          'list': videos.map((v) => v.path).toList(),
          'index': index,
        }),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<VideoFile> videos) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 11,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => context.push('/player', extra: {
            'path': video.path,
            'list': videos.map((v) => v.path).toList(),
            'index': index,
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.darkCard),
                VideoThumbnailWidget(videoPath: video.path, fit: BoxFit.cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 38),
                ),
                Positioned(
                  bottom: 8, left: 8, right: 8,
                  child: Text(
                    video.nameWithoutExtension,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
