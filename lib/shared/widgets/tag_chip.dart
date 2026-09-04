import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 小さなラベル表示用チップ。苦手分野やカテゴリ名に使う。
///
/// [onTap] を渡すとタップ可能になり、末尾に矢印アイコンが付く
/// （「タップできる」ことが色だけで伝わらないようにするため）。
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color = AppColors.info,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 14, color: color),
        ],
      ],
    );

    final decoration = BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    );

    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: decoration,
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
