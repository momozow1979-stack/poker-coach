import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/application/progress_providers.dart';
import '../../../profile/domain/growth_rank.dart';
import '../../../profile/domain/learning_stats.dart';
import '../../../profile/domain/user_profile.dart';

/// ホーム上部の挨拶・レベル・連続学習日数・上達スコア。
///
/// グラデーションの「主役」面にして、フラットなカードが並ぶ中で
/// 一番最初に目に入る場所だとわかるようにする。
///
/// 以前は「次のレベルまで」の進捗バー（生涯の累積回答数が母数）と、
/// 上達スコアのリング（直近7日の正答率が母数）を別カードで両方
/// 出していたが、どちらも「今どれくらい進んでいるか」を示す見た目が
/// 重複していたため、進捗バーは削除しリングだけに一本化した。
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.profile, required this.stats});

  final UserProfile profile;
  final LearningStats stats;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'こんばんは';
    if (hour < 11) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = (stats.accuracyLast7Days * 100).round().clamp(0, 100);
    final hasComparison = stats.hasPreviousWeekData;
    final deltaPt = hasComparison
        ? ((stats.accuracyLast7Days - stats.accuracyPreviousWeek) * 100).round()
        : null;
    final rank = ref.watch(growthRankProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardGlow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting、${profile.displayName}さん',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Lv.${rank.level}  ${rank.label} ${rank.emoji}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _StreakBadge(days: stats.streakDays),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _DashedDivider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
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
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
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
        ],
      ),
    );
  }
}

/// 上下2枚のカードを1枚に統合したことを示す、控えめな区切り線。
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          const gap = 4.0;
          final count = (constraints.maxWidth / (dashWidth + gap)).floor();
          return Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                Container(width: dashWidth, height: 1, color: AppColors.border),
                if (i != count - 1) const SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
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

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.rewardGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppColors.cardGlow(color: AppColors.rewardDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: Color(0xFF3A1E00),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$days日連続',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A1E00),
            ),
          ),
        ],
      ),
    );
  }
}
