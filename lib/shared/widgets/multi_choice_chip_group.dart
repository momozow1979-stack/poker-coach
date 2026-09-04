import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 複数選択のチップ群。[ChoiceChipGroup] の複数選択版。
///
/// オンボーディングの「学びたい分野」のように、
/// 0 個以上を自由に選ばせたい場面で使う。
class MultiChoiceChipGroup<T> extends StatelessWidget {
  const MultiChoiceChipGroup({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onToggle,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          _Chip(
            label: labelBuilder(value),
            isSelected: selected.contains(value),
            onTap: () => onToggle(value),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accent : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget,
            minWidth: AppSpacing.minTapTarget + 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: isSelected ? AppColors.onAccent : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
