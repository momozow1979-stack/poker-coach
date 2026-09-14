import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/domain/learning_stats.dart';
import '../../../quiz/domain/learning_stage.dart';

const _stageColors = {
  LearningStage.foundations: AppColors.accent,
  LearningStage.postflop: AppColors.info,
  LearningStage.advanced: AppColors.rangeThreeBet,
};

/// 全11カテゴリを3ステージに束ねた学習ロードマップ。
///
/// 表示するのは「そのステージで今まで答えた分の正答率」で、
/// カテゴリの出題プール全体をどれだけ消化したかではない
/// （プール消化率を出すには、カテゴリごとの総問題数を別途持つ必要がある）。
class LearningRoadmapCard extends StatelessWidget {
  const LearningRoadmapCard({super.key, required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final categoryStats = stats.categoryStats;
    final progress = {
      for (final stage in LearningStage.values)
        stage: stage.progressFrom(categoryStats),
    };
    final current = _currentStage(progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '学習ロードマップ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const Text(
              '全11カテゴリ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        for (var i = 0; i < LearningStage.values.length; i++)
          _StageRow(
            index: i + 1,
            stage: LearningStage.values[i],
            progress: progress[LearningStage.values[i]]!,
            isCurrent: LearningStage.values[i] == current,
            showDivider: i > 0,
          ),
      ],
    );
  }

  LearningStage _currentStage(
    Map<LearningStage, ({int correct, int total})> progress,
  ) {
    for (final stage in LearningStage.values) {
      final p = progress[stage]!;
      final accuracy = p.total == 0 ? 0.0 : p.correct / p.total;
      if (p.total == 0 || accuracy < 0.8) return stage;
    }
    return LearningStage.values.last;
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.index,
    required this.stage,
    required this.progress,
    required this.isCurrent,
    required this.showDivider,
  });

  final int index;
  final LearningStage stage;
  final ({int correct, int total}) progress;
  final bool isCurrent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final accuracy = progress.total == 0
        ? 0.0
        : progress.correct / progress.total;
    final color = _stageColors[stage] ?? AppColors.accent;

    return Container(
      padding: EdgeInsets.only(top: showDivider ? AppSpacing.md : 4),
      margin: EdgeInsets.only(top: showDivider ? AppSpacing.md : 0),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stage.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '現在地',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      progress.total == 0
                          ? '未着手'
                          : '正答率 ${(accuracy * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  stage.categoryLabels,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: accuracy,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
