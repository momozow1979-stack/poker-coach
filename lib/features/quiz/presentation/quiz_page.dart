import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../range_chart/application/range_providers.dart';
import '../application/quiz_providers.dart';
import 'widgets/quiz_session_view.dart';
import 'widgets/quiz_summary_view.dart';

/// 毎日の10問クイズ画面。
class QuizPage extends ConsumerWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(dailyQuizSessionProvider);
    final controller = ref.read(dailyQuizSessionProvider.notifier);
    final quiz = session.currentQuiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日の10問'),
        actions: [
          IconButton(
            tooltip: 'ハンドトレーナー',
            onPressed: () => context.go(AppRoutes.trainer),
            icon: const Icon(Icons.sports_esports_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: session.progress,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${session.currentIndex.clamp(0, session.totalCount - 1) + 1} / ${session.totalCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: quiz == null
            ? QuizSummaryView(
                session: session,
                onRestart: controller.restart,
                onGoHome: () => context.go(AppRoutes.home),
                onOpenTrainer: () => context.go(AppRoutes.trainer),
              )
            : QuizSessionView(
                quiz: quiz,
                selectedChoiceId: session.revealedChoiceId,
                onAnswer: controller.answer,
                onNext: controller.next,
                onOpenRange: (spotId) => _openRange(context, ref, spotId),
              ),
      ),
    );
  }

  void _openRange(BuildContext context, WidgetRef ref, String spotId) {
    final chart = ref.read(rangeChartByIdProvider(spotId));
    if (chart == null) return;
    ref.read(selectedTableTypeProvider.notifier).select(chart.spot.tableType);
    ref.read(selectedPositionProvider.notifier).select(chart.spot.heroPosition);
    context.go(AppRoutes.range);
  }
}
