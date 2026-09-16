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
import '../../coach/application/coach_providers.dart';
import '../../coach/domain/coach_message.dart';
import '../../hand_trainer/application/trainer_providers.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../profile/application/learning_providers.dart';
import '../../quiz/application/quiz_providers.dart';
import 'widgets/coach_message_card.dart';
import 'widgets/daily_quiz_card.dart';
import 'widgets/home_header.dart';
import 'widgets/learning_roadmap_card.dart';
import 'widgets/trainer_spotlight_card.dart';
import 'widgets/weak_areas_block.dart';

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
    final onboarding = ref.watch(onboardingAnswersProvider);
    final todayScenario = ref.watch(todayScenarioProvider);

    final weakCategories = stats.weakCategories();
    // 苦手分野がまだ検出できていない間は、オンボーディングで選んだ
    // 「学びたい分野」を代わりに見せる。どちらも同じカテゴリ別クイズへ導く。
    final usingFocusFallback = weakCategories.isEmpty;
    final focusCategories = usingFocusFallback
        ? (onboarding?.focusCategories ?? const [])
        : weakCategories;

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
            if (briefing.of(CoachMessageType.focus) case final focus?) ...[
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: CoachMessageCard(
                  message: focus,
                  icon: Icons.center_focus_strong_rounded,
                  accent: AppColors.info,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DailyQuizCard(
                        session: session,
                        onStart: () => context.go(AppRoutes.quiz),
                      ),
                    ),
                    if (todayScenario != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TrainerSpotlightCard(
                          scenario: todayScenario,
                          onTap: () {
                            ref
                                .read(trainerSessionProvider.notifier)
                                .start(todayScenario.id);
                            context.go(AppRoutes.trainerPlay(todayScenario.id));
                          },
                          onBrowseAll: () => context.go(AppRoutes.trainer),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WeakAreasBlock(
                      categories: focusCategories,
                      usingFallback: usingFocusFallback,
                      onCategoryTap: (category) =>
                          context.go(AppRoutes.categoryQuiz(category.id)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.lg),
                    LearningRoadmapCard(stats: stats),
                  ],
                ),
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
