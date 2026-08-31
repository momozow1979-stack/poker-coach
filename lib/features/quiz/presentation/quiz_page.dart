import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../range_chart/application/range_providers.dart';
import '../application/quiz_providers.dart';
import '../domain/quiz.dart';
import 'widgets/quiz_choice_button.dart';
import 'widgets/quiz_explanation_view.dart';
import 'widgets/quiz_situation_card.dart';
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
              )
            : _QuizQuestionView(
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

class _QuizQuestionView extends StatelessWidget {
  const _QuizQuestionView({
    required this.quiz,
    required this.selectedChoiceId,
    required this.onAnswer,
    required this.onNext,
    required this.onOpenRange,
  });

  final Quiz quiz;
  final String? selectedChoiceId;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;
  final ValueChanged<String> onOpenRange;

  @override
  Widget build(BuildContext context) {
    final isRevealed = selectedChoiceId != null;
    final rangeSpotId = quiz.explanation.relatedRangeSpotId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            _Badge(text: quiz.category.label, color: AppColors.info),
            const SizedBox(width: AppSpacing.sm),
            _Badge(text: quiz.difficulty.label, color: AppColors.textMuted),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (quiz.situation case final situation?) ...[
          QuizSituationCard(situation: situation),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          quiz.question,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < quiz.choices.length; i++)
          FadeSlideIn(
            // 問題が変わるたびに選択肢が順に立ち上がる。
            key: ValueKey('${quiz.id}-${quiz.choices[i].id}'),
            delay: Duration(milliseconds: 60 * i),
            child: QuizChoiceButton(
              label: quiz.choices[i].label,
              isRevealed: isRevealed,
              isCorrectChoice: quiz.choices[i].id == quiz.correctChoiceId,
              isSelected: quiz.choices[i].id == selectedChoiceId,
              onTap: () => onAnswer(quiz.choices[i].id),
            ),
          ),
        if (isRevealed) ...[
          const SizedBox(height: AppSpacing.sm),
          QuizExplanationView(
            quiz: quiz,
            isCorrect: quiz.isCorrect(selectedChoiceId!),
            onOpenRange: rangeSpotId == null
                ? null
                : () => onOpenRange(rangeSpotId),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('次の問題へ'),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
