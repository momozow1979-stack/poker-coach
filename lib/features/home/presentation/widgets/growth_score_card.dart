import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/domain/growth_rank.dart';
import '../../../profile/domain/learning_stats.dart';

/// 上達スコア（直近7日の正答率）と、動物アイコンの成長ランクを1枚にまとめる。
///
/// 「上位◯%」のような他ユーザーとの比較は、集計する仕組みが無いため
/// 出していない（[GrowthRank] のドキュメント参照）。
class GrowthScoreCard extends StatelessWidget {
  const GrowthScoreCard({super.key, required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final score = (stats.accuracyLast7Days * 100).round().clamp(0, 100);
    final hasComparison = stats.hasPreviousWeekData;
    final deltaPt = hasComparison
        ? ((stats.accuracyLast7Days - stats.accuracyPreviousWeek) * 100).round()
        : null;
    final rank = GrowthRank.forStats(
      accuracy: stats.accuracy,
      totalAnswered: stats.totalAnswered,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.accent,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '上達スコア',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasComparison
                        ? (deltaPt! >= 0
                              ? '先週より+${deltaPt}pt'
                              : '先週より${deltaPt}pt')
                        : '直近7日の正答率',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _RankLadder(current: rank),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${rank.emoji} '),
                TextSpan(
                  text: rank.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' ランク'),
              ],
            ),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankLadder extends StatelessWidget {
  const _RankLadder({required this.current});

  final GrowthRank current;

  @override
  Widget build(BuildContext context) {
    final ranks = GrowthRank.values;
    final currentIndex = current.index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < ranks.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: i <= currentIndex ? 1 : 0.35,
                      child: Text(
                        ranks[i].emoji,
                        style: TextStyle(fontSize: 16.0 + i * 3.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ranks[i].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: i == currentIndex
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: i == currentIndex
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
