import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/video_file.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/video_list_tile.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../widgets/sort_bar.dart';
import '../data/media_service.dart';

class FolderScreen extends StatefulWidget {
  final String folderPath;
  const FolderScreen({super.key, required this.folderPath});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    // isDark not needed here — theme is applied globally
    context.watch<SettingsProvider>();
    final folder = library.folders[widget.folderPath];

    if (folder == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Dossier introuvable'),
        ),
        body: const Center(child: Text('Ce dossier n\'existe plus.')),
      );
    }

    final videos = folder.videos;
    final firstVideo = videos.isNotEmpty ? videos.first : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with first video thumbnail
          SliverAppBar(
            expandedHeight: videos.isNotEmpty ? 220 : 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _handleMenuAction(v, context, folder),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'sort', child: Text('Trier par...')),
                  PopupMenuItem(value: 'refresh', child: Text('Actualiser')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    folder.countLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              background: firstVideo != null
                  ? _FolderHeroBackground(video: firstVideo)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.darkCard, AppColors.darkBackground],
                        ),
                      ),
                    ),
            ),
          ),

          // Sort bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SortBar(
                current: library.sortMode,
                ascending: library.sortAscending,
                onSort: (mode) => library.setSortMode(mode),
              ),
            ),
          ),

          // Videos
          if (_isGridView)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _VideoGridItem(
                    video: videos[index],
                    allVideos: videos,
                    index: index,
                  ),
                  childCount: videos.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 16 / 11,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => VideoListTile(
                    video: videos[index],
                    onTap: () => _openVideo(context, videos, index),
                    onLongPress: () => _showActionSheet(context, videos[index]),
                  ),
                  childCount: videos.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _openVideo(BuildContext context, List<VideoFile> videos, int index) {
    context.push('/player', extra: {
      'path': videos[index].path,
      'list': videos.map((v) => v.path).toList(),
      'index': index,
    });
  }

  void _handleMenuAction(String action, BuildContext context, VideoFolder folder) {
    if (action == 'refresh') {
      context.read<LibraryProvider>().refresh();
    } else if (action == 'sort') {
      _showSortDialog(context);
    }
  }

  void _showSortDialog(BuildContext context) {
    final library = context.read<LibraryProvider>();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trier par', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final mode in SortMode.values)
              ListTile(
                title: Text(_sortLabel(mode)),
                leading: Icon(
                  library.sortMode == mode
                      ? (library.sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                      : Icons.sort_rounded,
                  color: library.sortMode == mode ? AppColors.accentBlue : null,
                ),
                selected: library.sortMode == mode,
                selectedColor: AppColors.accentBlue,
                onTap: () {
                  library.setSortMode(mode);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.name:
        return 'Nom';
      case SortMode.date:
        return 'Date';
      case SortMode.duration:
        return 'Durée';
      case SortMode.size:
        return 'Taille';
    }
  }

  void _showActionSheet(BuildContext context, VideoFile video) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _VideoActionSheet(video: video),
    );
  }
}

class _FolderHeroBackground extends StatefulWidget {
  final VideoFile video;
  const _FolderHeroBackground({required this.video});

  @override
  State<_FolderHeroBackground> createState() => _FolderHeroBackgroundState();
}

class _FolderHeroBackgroundState extends State<_FolderHeroBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: _loadThumb(),
          builder: (_, snapshot) {
            if (snapshot.data != null) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            return Container(color: AppColors.darkCard);
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<dynamic> _loadThumb() {
    return MediaService.getThumbnail(widget.video.path);
  }
}

class _VideoGridItem extends StatelessWidget {
  final VideoFile video;
  final List<VideoFile> allVideos;
  final int index;

  const _VideoGridItem({
    required this.video,
    required this.allVideos,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player', extra: {
        'path': video.path,
        'list': allVideos.map((v) => v.path).toList(),
        'index': index,
      }),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.darkCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoThumbnailWidget(videoPath: video.path, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 36),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                video.nameWithoutExtension,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (video.duration != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.formattedDuration,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoActionSheet extends StatelessWidget {
  final VideoFile video;
  const _VideoActionSheet({required this.video});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video info header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 42,
                  child: VideoThumbnailWidget(videoPath: video.path, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.nameWithoutExtension,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(video.formattedDuration,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Actions
          _ActionTile(
            icon: Icons.play_arrow_rounded,
            label: 'Lire',
            onTap: () {
              Navigator.pop(context);
              context.push('/player', extra: {'path': video.path, 'list': [video.path], 'index': 0});
            },
          ),
          _ActionTile(
            icon: Icons.favorite_border_rounded,
            label: 'Ajouter aux favoris',
            onTap: () {
              Navigator.pop(context);
              final favorites = context.read<FavoritesProvider>();
              final isFav = favorites.isFavorite(video.path);
              if (isFav) {
                favorites.removeFavorite(video.path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retiré des favoris')),
                );
              } else {
                favorites.addFavorite(video.path, video.name, video.folderName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ajouté aux favoris')),
                );
              }
            },
          ),
          _ActionTile(
            icon: Icons.drive_file_move_rounded,
            label: 'Déplacer vers...',
            onTap: () {
              Navigator.pop(context);
              _showMoveDialog(context, video, move: true);
            },
          ),
          _ActionTile(
            icon: Icons.copy_rounded,
            label: 'Copier vers...',
            onTap: () {
              Navigator.pop(context);
              _showMoveDialog(context, video, move: false);
            },
          ),
          _ActionTile(
            icon: Icons.edit_rounded,
            label: 'Renommer',
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context);
            },
          ),
          _ActionTile(
            icon: Icons.delete_rounded,
            label: 'Supprimer',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context);
            },
          ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: video.nameWithoutExtension);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nouveau nom'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LibraryProvider>().renameVideo(video, controller.text.trim());
            },
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${video.nameWithoutExtension}" définitivement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<LibraryProvider>().deleteVideo(video);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(BuildContext context, VideoFile video, {required bool move}) {
    final library = context.read<LibraryProvider>();
    final folders = library.sortedFolders
        .where((f) => f.path != video.folderPath)
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (_) => _FolderPickerSheet(
        title: move ? 'Déplacer vers' : 'Copier vers',
        folders: folders,
        onSelect: (folderPath) async {
          Navigator.pop(context);
          bool success;
          if (move) {
            success = await library.moveVideo(video, folderPath);
          } else {
            success = await library.copyVideo(video, folderPath);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success
                    ? (move ? 'Vidéo déplacée' : 'Vidéo copiée')
                    : 'Opération échouée'),
              ),
            );
          }
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}


class _FolderPickerSheet extends StatelessWidget {
  final String title;
  final List<VideoFolder> folders;
  final ValueChanged<String> onSelect;

  const _FolderPickerSheet({
    required this.title,
    required this.folders,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (folders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucun dossier disponible',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (context, i) {
                  final folder = folders[i];
                  return ListTile(
                    leading: Icon(
                      Icons.folder_rounded,
                      color: AppColors.folderColors[folder.colorIndex],
                    ),
                    title: Text(folder.name),
                    subtitle: Text(folder.countLabel),
                    onTap: () => onSelect(folder.path),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
  }
}
