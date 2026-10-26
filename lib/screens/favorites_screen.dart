import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/favorites_provider.dart';
import '../models/favorite_entry.dart';
import '../widgets/video_thumbnail_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Favoris', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (favorites.count > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Tout supprimer',
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      body: favorites.loading
          ? const Center(child: CircularProgressIndicator())
          : favorites.entries.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, favorites),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucun favori', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Appuyez longuement sur une vidéo pour l\'ajouter aux favoris',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, FavoritesProvider favorites) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: favorites.entries.length,
      itemBuilder: (context, index) {
        final entry = favorites.entries[index];
        return _FavoriteTile(
          entry: entry,
          onPlay: () => _playVideo(context, entry),
          onRemove: () => favorites.removeFavorite(entry.videoPath),
        );
      },
    );
  }

  void _playVideo(BuildContext context, FavoriteEntry entry) {
    if (File(entry.videoPath).existsSync()) {
      context.push('/player', extra: {
        'path': entry.videoPath,
        'list': [entry.videoPath],
        'index': 0,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier introuvable')),
      );
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider les favoris'),
        content: const Text('Supprimer tous les favoris ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<FavoritesProvider>().clearAll();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final FavoriteEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _FavoriteTile({
    required this.entry,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('fav_${entry.videoPath}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.favorite_border_rounded, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onPlay,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 48,
                  child: VideoThumbnailWidget(
                    videoPath: entry.videoPath,
                    fit: BoxFit.cover,
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
                      _nameWithoutExt(entry.videoName),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.folder_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.folderName,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Favorite remove button
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nameWithoutExt(String name) {
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }
}
