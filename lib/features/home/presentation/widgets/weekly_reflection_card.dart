import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../../../shared/widgets/trend_chart.dart';
import '../../../profile/domain/learning_stats.dart';

/// ホームの「今週の振り返り」カード。
///
/// 単なる「正答率の推移」グラフより一段踏み込み、
/// 既に計算済みだが表に出ていなかった [LearningStats] の値
/// （直近7日の正答率・先週比・連続記録）を1枚にまとめる。
///
/// 先週比はデータが無い（まだ1週間経っていない）ときに 0% と
/// 見せかけるのではなく、正直に「比較にはあと1週間必要です」と出す。
class WeeklyReflectionCard extends StatelessWidget {
  const WeeklyReflectionCard({super.key, required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final thisWeek = (stats.accuracyLast7Days * 100).round();
    final hasComparison = stats.hasPreviousWeekData;
    final deltaPt = hasComparison
        ? ((stats.accuracyLast7Days - stats.accuracyPreviousWeek) * 100).round()
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '今週の正答率',
                  value: '$thisWeek',
                  unit: '%',
                  icon: Icons.trending_up_rounded,
                  valueColor: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: '連続学習',
                  value: '${stats.streakDays}',
                  unit: '日',
                  icon: Icons.local_fire_department_rounded,
                  valueColor: AppColors.rewardDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasComparison
                    ? (deltaPt! >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                    : Icons.hourglass_empty_rounded,
                size: 16,
                color: hasComparison
                    ? (deltaPt! >= 0 ? AppColors.accent : AppColors.danger)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  hasComparison
                      ? (deltaPt! >= 0
                            ? '先週より+${deltaPt}pt伸びています'
                            : '先週より${deltaPt}pt下がっています')
                      : '比較にはあと1週間必要です',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '直近14日',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendChart(
            points: [
              for (final day in stats.dailyAccuracy())
                TrendPoint(
                  label: '${day.day.month}/${day.day.day}',
                  value: day.accuracy,
                ),
            ],
            height: 88,
          ),
        ],
      ),
    );
  }
}
