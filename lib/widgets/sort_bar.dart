import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';

class SortBar extends StatelessWidget {
  final SortMode current;
  final bool ascending;
  final void Function(SortMode) onSort;

  const SortBar({
    super.key,
    required this.current,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: SortMode.values.map((mode) {
          final isSelected = current == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSort(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentBlue.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.accentBlue : AppColors.textMuted.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label(mode),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.accentBlue : AppColors.textMuted,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(
                        ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 14,
                        color: AppColors.accentBlue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(SortMode mode) {
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
}
