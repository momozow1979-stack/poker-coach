import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../domain/daily_quiz_session.dart';
import '../../domain/quiz_category.dart';

/// 10問終了後のまとめ。
class QuizSummaryView extends StatelessWidget {
  const QuizSummaryView({
    super.key,
    required this.session,
    required this.onRestart,
    required this.onGoHome,
    this.onOpenTrainer,
  });

  final DailyQuizSession session;
  final VoidCallback onRestart;
  final VoidCallback onGoHome;

  /// 「他の練習」としてハンドトレーナーへ導く。null なら表示しない。
  final VoidCallback? onOpenTrainer;

  /// このセッションで間違えたカテゴリ。
  List<QuizCategory> get _missedCategories {
    final categories = <QuizCategory>{};
    for (final attempt in session.attempts.values) {
      if (!attempt.isCorrect) categories.add(attempt.category);
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = (session.accuracy * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '今日の10問おつかれさまでした',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: '正解数',
                      value: '${session.correctCount}',
                      unit: '/ ${session.totalCount}',
                      icon: Icons.check_rounded,
                      valueColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: '正答率',
                      value: '$accuracy',
                      unit: '%',
                      icon: Icons.percent_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '次回の課題',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _missedCategories.isEmpty
                    ? '全問正解です。明日は少し難しめの問題に挑戦しましょう。'
                    : '${_missedCategories.map((category) => category.label).join(' / ')} '
                          'を重点的に復習しましょう。間違えた問題の「よくあるミス」をもう一度読むのが近道です。',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onOpenTrainer != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: onOpenTrainer,
            borderColor: AppColors.info.withValues(alpha: 0.4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    size: 22,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '他の練習: ハンドトレーナー',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '1ハンドを通してプリフロップからリバーまで練習します',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onGoHome, child: const Text('ホームに戻る')),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRestart, child: const Text('もう一度解く')),
      ],
    );
  }
}
