import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 学習タブの3つの入り口。
enum LearningMode {
  quiz('座学', Icons.menu_book_rounded),
  trainer('ハンドトレーナー', Icons.route_rounded),
  practice('AI相手に練習', Icons.smart_toy_outlined);

  const LearningMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 学習タブのどのページからでも、他の2つへすぐ切り替えられる帯。
///
/// 「今日の10問しか選べない」とならないよう、常に3つの入り口を見せておく。
class LearningModeBar extends StatelessWidget {
  const LearningModeBar({super.key, required this.current});

  final LearningMode current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (final mode in LearningMode.values) ...[
            if (mode != LearningMode.values.first)
              const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModeButton(mode: mode, isActive: mode == current),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.isActive});

  final LearningMode mode;
  final bool isActive;

  void _go(BuildContext context) {
    if (isActive) return;
    switch (mode) {
      case LearningMode.quiz:
        context.go(AppRoutes.quiz);
      case LearningMode.trainer:
        context.go(AppRoutes.trainer);
      case LearningMode.practice:
        context.go(AppRoutes.practiceTable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textMuted;
    return Material(
      color: isActive
          ? AppColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: () => _go(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                mode.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
