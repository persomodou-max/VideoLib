import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/library_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/folder_card.dart';
import '../widgets/app_logo.dart';
import '../data/permission_service.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0=Files, 1=Favorites, 2=History(navigated), 3=Settings(navigated)
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeWithPermission();
      if (!mounted) return;
      final history = context.read<HistoryProvider>();
      final favorites = context.read<FavoritesProvider>();
      final settings = context.read<SettingsProvider>();
      await history.load();
      await favorites.load();
      if (settings.autoDeleteHistory) {
        await history.autoCleanIfNeeded();
      }
      await favorites.cleanMissingFiles();
    });
  }

  Future<void> _initializeWithPermission() async {
    final granted = await PermissionService.requestWithRationale(context);
    if (granted && mounted) {
      context.read<LibraryProvider>().initialize();
    } else if (!granted && mounted) {
      // Still try to initialize (some files may be accessible)
      context.read<LibraryProvider>().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          final sidebarBg = isDark ? AppColors.darkSidebar : AppColors.lightSidebar;
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(context, sidebarBg),
                Container(
                  width: 1,
                  color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFE5E7EB),
                ),
                Expanded(child: _buildMainContent(context)),
              ],
            ),
          );
        }

        // Compact layout: bottom navigation bar
        return Scaffold(
          body: _buildMainContent(context),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex.clamp(0, 1),
            onDestinationSelected: (i) {
              if (i == 2) {
                context.go('/home/history');
                return;
              }
              if (i == 3) {
                context.go('/home/settings');
                return;
              }
              setState(() => _selectedIndex = i);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.folder_rounded), label: 'Fichiers'),
              NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'Favoris'),
              NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Récents'),
              NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, Color bg) {
    final isDark = context.watch<SettingsProvider>().isDark;
    final items = [
      (Icons.folder_rounded, 'Fichiers', 0),
      (Icons.favorite_rounded, 'Favoris', 1),
      (Icons.history_rounded, 'Récents', 2),
      (Icons.settings_rounded, 'Paramètres', 3),
    ];

    return Container(
      width: 72,
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Logo
            const AppLogo(size: 42, showShadow: false),
            const SizedBox(height: 32),

            // Nav items
            ...items.map((item) {
              final isSelected = _selectedIndex == item.$3;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    if (item.$3 == 3) {
                      context.go('/home/settings');
                      return;
                    }
                    if (item.$3 == 2) {
                      context.go('/home/history');
                      return;
                    }
                    setState(() => _selectedIndex = item.$3);
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppConstants.animNormal,
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isSelected
                              ? AppColors.accentBlue.withValues(alpha: 0.15)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          item.$1,
                          color: isSelected
                              ? AppColors.accentBlue
                              : (isDark ? AppColors.textMuted : const Color(0xFF9CA3AF)),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.accentBlue
                              : (isDark ? AppColors.textMuted : const Color(0xFF9CA3AF)),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const Spacer(),

            // User avatar / profile
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isDark ? AppColors.textMuted : Colors.grey.shade400,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _FolderListView(onSearch: () => context.go('/home/search'));
      case 1:
        return const FavoritesScreen();
      default:
        return _FolderListView(onSearch: () => context.go('/home/search'));
    }
  }
}

class _FolderListView extends StatelessWidget {
  final VoidCallback onSearch;
  const _FolderListView({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDark = context.watch<SettingsProvider>().isDark;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lib Des Vidéos',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      onPressed: () => library.refresh(),
                      icon: library.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search bar (fake, navigates to real SearchScreen)
                GestureDetector(
                  onTap: onSearch,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : const Color(0xFFEEF2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: isDark ? AppColors.textMuted : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Rechercher un fichier...',
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // "All Videos" shortcut
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _AllVideosTile(
              count: library.totalVideoCount,
              onTap: () => context.go('/home/all-videos'),
            ),
          ),
        ),

        // Loading indicator
        if (library.loading && !library.initialized)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )

        // Empty state
        else if (library.sortedFolders.isEmpty && library.initialized)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 64,
                    color: isDark ? AppColors.textMuted : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune vidéo trouvée',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vérifiez les autorisations de stockage',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => PermissionService.openSettings(),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Ouvrir les paramètres'),
                  ),
                ],
              ),
            ),
          )

        // Folder list
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final folder = library.sortedFolders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FolderCard(
                      folder: folder,
                      onTap: () => context.go(
                        '/home/folder?path=${Uri.encodeComponent(folder.path)}',
                      ),
                    ),
                  );
                },
                childCount: library.sortedFolders.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _AllVideosTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AllVideosTile({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentBlue.withValues(alpha: 0.15),
              AppColors.accentPurple.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentBlue.withValues(alpha: 0.8),
                    AppColors.accentPurple.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toutes les vidéos',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    '$count vidéo${count != 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
