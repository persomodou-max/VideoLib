import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/settings_provider.dart';
import '../providers/history_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ---- LECTURE ----
          _SectionHeader(title: 'Lecture'),
          _SettingsTile(
            icon: Icons.speed_rounded,
            label: 'Qualité vidéo par défaut',
            trailing: const Text('Auto', style: TextStyle(color: AppColors.textMuted)),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.skip_next_rounded,
            label: 'Lecture automatique',
            trailing: Switch(
              value: settings.autoPlay,
              onChanged: settings.setAutoPlay,
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.subtitles_rounded,
            label: 'Sous-titres',
            trailing: Text(
              settings.subtitleEnabled ? 'Activé' : 'Désactivé',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            onTap: () => settings.setSubtitleEnabled(!settings.subtitleEnabled),
          ),
          _SettingsTile(
            icon: Icons.repeat_rounded,
            label: 'Mode de lecture',
            trailing: Text(settings.playbackModeLabel, style: const TextStyle(color: AppColors.textMuted)),
            onTap: () => _showPlaybackModeSheet(context, settings),
          ),
          _SettingsTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Vitesse par défaut',
            trailing: Text('${settings.defaultSpeed}×', style: const TextStyle(color: AppColors.textMuted)),
            onTap: () => _showSpeedSheet(context, settings),
          ),

          const SizedBox(height: 8),
          _SectionHeader(title: 'Apparence'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            label: 'Mode nuit',
            trailing: Switch(
              value: settings.isDark,
              onChanged: (v) => settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.palette_rounded,
            label: 'Thème',
            trailing: Text(
              settings.isDark ? 'Sombre' : 'Clair',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            onTap: () => settings.setThemeMode(settings.isDark ? ThemeMode.light : ThemeMode.dark),
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'Langue',
            trailing: Text(
              settings.locale.languageCode == 'fr' ? 'Français' : 'English',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            onTap: () => _showLanguageSheet(context, settings),
          ),

          const SizedBox(height: 8),
          _SectionHeader(title: 'Historique'),
          _SettingsTile(
            icon: Icons.auto_delete_rounded,
            label: 'Suppression auto quotidienne',
            trailing: Switch(
              value: settings.autoDeleteHistory,
              onChanged: (v) async {
                await settings.setAutoDeleteHistory(v);
                if (v && context.mounted) {
                  await context.read<HistoryProvider>().autoCleanIfNeeded();
                }
              },
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Effacer l\'historique',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => _confirmClearHistory(context),
          ),

          const SizedBox(height: 8),
          _SectionHeader(title: 'À propos'),
          _SettingsTile(
            icon: Icons.info_rounded,
            label: 'Version',
            trailing: Text(AppConstants.appVersion, style: const TextStyle(color: AppColors.textMuted)),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.help_rounded,
            label: 'Aide & support',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => _showDeveloperInfo(context),
          ),
          _SettingsTile(
            icon: Icons.security_rounded,
            label: 'Autorisations',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => _showPermissionsInfo(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showPlaybackModeSheet(BuildContext context, SettingsProvider settings) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode de lecture', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...modes.map((m) => ListTile(
                  leading: Icon(m.$3),
                  title: Text(m.$2),
                  trailing: settings.playbackMode == m.$1
                      ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                      : null,
                  selected: settings.playbackMode == m.$1,
                  selectedColor: AppColors.accentBlue,
                  onTap: () {
                    settings.setPlaybackMode(m.$1);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSpeedSheet(BuildContext context, SettingsProvider settings) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vitesse de lecture', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: speeds.map((s) {
                final isSelected = settings.defaultSpeed == s;
                return ChoiceChip(
                  label: Text('$s×'),
                  selected: isSelected,
                  selectedColor: AppColors.accentBlue,
                  onSelected: (_) {
                    settings.setDefaultSpeed(s);
                    Navigator.pop(context);
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

  void _showLanguageSheet(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Langue', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final lang in [('fr', 'Français', '🇫🇷'), ('en', 'English', '🇬🇧')])
              ListTile(
                leading: Text(lang.$3, style: const TextStyle(fontSize: 24)),
                title: Text(lang.$2),
                trailing: settings.locale.languageCode == lang.$1
                    ? const Icon(Icons.check_rounded, color: AppColors.accentBlue)
                    : null,
                selected: settings.locale.languageCode == lang.$1,
                selectedColor: AppColors.accentBlue,
                onTap: () {
                  settings.setLocale(Locale(lang.$1));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text('Cette action supprimera tout l\'historique de lecture.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<HistoryProvider>().clearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historique effacé')),
              );
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Développeur', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            _DevInfoRow(
              icon: Icons.badge_rounded,
              label: 'Nom',
              value: 'Modou Sylla',
            ),
            const SizedBox(height: 12),
            _DevInfoRow(
              icon: Icons.school_rounded,
              label: 'Formation',
              value: 'Licence Informatique\nUniversité Gaston Berger\nSaint-Louis',
            ),
            const SizedBox(height: 12),
            _DevInfoRow(
              icon: Icons.email_rounded,
              label: 'Mail',
              value: 'sylla.modou1@ugb.edu.sn',
            ),
            const SizedBox(height: 12),
            _DevInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'Application',
              value: 'VidéoLib ${AppConstants.appVersion}',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showPermissionsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Autorisations'),
        content: const Text(
          'VidéoLib utilise les autorisations suivantes :\n\n'
          '• Stockage : accès aux vidéos stockées sur l\'appareil\n'
          '• Superposition d\'écran : mode picture-in-picture\n\n'
          'Aucune donnée n\'est envoyée à un serveur externe.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accentBlue, size: 22),
        title: Text(label),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DevInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DevInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accentBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
