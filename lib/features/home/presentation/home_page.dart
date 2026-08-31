import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/trend_chart.dart';
import '../../coach/application/coach_providers.dart';
import '../../coach/domain/coach_message.dart';
import '../../profile/application/learning_providers.dart';
import '../../quiz/application/quiz_providers.dart';
import 'widgets/coach_message_card.dart';
import 'widgets/daily_quiz_card.dart';
import 'widgets/home_header.dart';

/// ホーム画面。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final stats = ref.watch(learningStatsProvider);
    final session = ref.watch(dailyQuizSessionProvider);
    final briefing = ref.watch(coachBriefingProvider);
    final reviews = ref.watch(handReviewHistoryProvider);
    final weakCategories = stats.weakCategories();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            FadeSlideIn(
              child: HomeHeader(profile: profile, stats: stats),
            ),
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: DailyQuizCard(
                session: session,
                onStart: () => context.go(AppRoutes.quiz),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _TrainerEntryCard(
                onTap: () => context.go(AppRoutes.trainer),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'AIコーチ',
              subtitle: '学習履歴から今日のテーマを選んでいます',
            ),
            const SizedBox(height: AppSpacing.md),
            if (briefing.of(CoachMessageType.daily) case final daily?)
              CoachMessageCard(message: daily),
            const SizedBox(height: AppSpacing.md),
            if (briefing.of(CoachMessageType.focus) case final focus?)
              CoachMessageCard(
                message: focus,
                icon: Icons.center_focus_strong_rounded,
                accent: AppColors.info,
              ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: '正答率の推移', subtitle: '直近14日'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: TrendChart(
                points: [
                  for (final day in stats.dailyAccuracy())
                    TrendPoint(
                      label: '${day.day.month}/${day.day.day}',
                      value: day.accuracy,
                    ),
                ],
                height: 88,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: '苦手分野',
              subtitle: weakCategories.isEmpty
                  ? '各カテゴリ3問以上で判定されます'
                  : 'ここを直すと全体が伸びます',
              action: TextButton(
                onPressed: () => context.go(AppRoutes.profile),
                child: const Text('詳しく'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: weakCategories.isEmpty
                  ? const Text(
                      'まだ苦手分野は検出されていません。今日の10問を解き進めると自動で見つかります。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final category in weakCategories)
                          TagChip(
                            label: category.label,
                            color: AppColors.danger,
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: '最近のハンドレビュー',
              action: TextButton(
                onPressed: () => context.go(AppRoutes.reviewInput),
                child: const Text('レビューする'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (reviews.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: 'まだレビューがありません',
                  message: '気になったハンドを1つ入力すると、AIが振り返りを作ります。',
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.reviewInput),
                    child: const Text('ハンドをレビューする'),
                  ),
                ),
              )
            else
              for (final review in reviews.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    onTap: () => context.go(AppRoutes.reviewInput),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Text(
                            '${review.score}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                review.result.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// ホームから意思決定トレーナーへの導線。
///
/// 新しく入った人にとって、レビュータブの奥にあるだけでは見つからない。
/// 「今日の10問」の次にやることとして、ここに置く。
class _TrainerEntryCard extends StatelessWidget {
  const _TrainerEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
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
                  '1ハンド通して練習する',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'プリフロップからリバーまで、各場面で自分で選びます',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
