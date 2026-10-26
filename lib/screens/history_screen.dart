import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/history_provider.dart';
import '../models/history_entry.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (history.count > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Tout effacer',
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: history.loading
          ? const Center(child: CircularProgressIndicator())
          : history.entries.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, history),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucun historique', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Les vidéos regardées apparaîtront ici',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, HistoryProvider history) {
    // Group by date
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in history.entries) {
      final label = entry.formattedDate;
      grouped.putIfAbsent(label, () => []).add(entry);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: grouped.entries.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(
                group.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...group.value.map((entry) => _HistoryTile(
                  entry: entry,
                  onPlay: () => _playVideo(context, entry),
                  onDelete: () => context.read<HistoryProvider>().deleteEntry(entry.id!),
                )),
          ],
        );
      }).toList(),
    );
  }

  void _playVideo(BuildContext context, HistoryEntry entry) {
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

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text('Supprimer tout l\'historique de lecture ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<HistoryProvider>().clearAll();
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = entry.totalDuration != null && entry.totalDuration!.inSeconds > 0
        ? (entry.lastPosition.inSeconds / entry.totalDuration!.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Dismissible(
      key: Key(entry.videoPath),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onPlay,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoThumbnailWidget(videoPath: entry.videoPath, fit: BoxFit.cover),
                      if (progress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.black38,
                            color: AppColors.accentBlue,
                            minHeight: 3,
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
                      entry.videoName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.folder_rounded, size: 12, color: AppColors.textMuted),
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
                    if (entry.lastPosition.inSeconds > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        _resumeLabel(entry),
                        style: TextStyle(fontSize: 11, color: AppColors.accentBlue),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.play_arrow_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _resumeLabel(HistoryEntry entry) {
    final pos = entry.lastPosition;
    final h = pos.inHours;
    final m = pos.inMinutes.remainder(60);
    final s = pos.inSeconds.remainder(60);
    final formatted = h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return 'Reprendre à $formatted';
  }
}
