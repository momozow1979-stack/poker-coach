import 'dart:async';

import 'package:confetti/confetti.dart';
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

class _QuizQuestionView extends StatefulWidget {
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
  State<_QuizQuestionView> createState() => _QuizQuestionViewState();
}

class _QuizQuestionViewState extends State<_QuizQuestionView> {
  static const _confettiDuration = Duration(milliseconds: 600);
  late final ConfettiController _confetti = ConfettiController(
    duration: _confettiDuration,
  );

  // ConfettiWidget は常時ツリーに置いたままだと、再生が終わったあとも
  // 内部の Ticker が止まりきらず `tester.pumpAndSettle()` がタイムアウトする
  // （confetti パッケージの既知の挙動）。祝っている間だけツリーに載せ、
  // 終わったら Timer で確実に外す。
  bool _showConfetti = false;
  Timer? _confettiHideTimer;

  @override
  void didUpdateWidget(covariant _QuizQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 「未回答 → 正解」に変わった瞬間だけ祝う。誤答や、既に表示済みの
    // 問題を再ビルドしただけのときには鳴らさない。
    final justAnsweredCorrectly =
        oldWidget.selectedChoiceId == null &&
        widget.selectedChoiceId != null &&
        widget.quiz.isCorrect(widget.selectedChoiceId!);
    if (justAnsweredCorrectly) _playConfetti();
  }

  void _playConfetti() {
    _confettiHideTimer?.cancel();
    setState(() => _showConfetti = true);
    _confetti.play();
    _confettiHideTimer = Timer(_confettiDuration, () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  @override
  void dispose() {
    _confettiHideTimer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final selectedChoiceId = widget.selectedChoiceId;
    final isRevealed = selectedChoiceId != null;
    final rangeSpotId = quiz.explanation.relatedRangeSpotId;

    return Stack(
      children: [
        ListView(
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
                  onTap: () => widget.onAnswer(quiz.choices[i].id),
                ),
              ),
            if (isRevealed) ...[
              const SizedBox(height: AppSpacing.sm),
              QuizExplanationView(
                quiz: quiz,
                isCorrect: quiz.isCorrect(selectedChoiceId),
                onOpenRange: rangeSpotId == null
                    ? null
                    : () => widget.onOpenRange(rangeSpotId),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('次の問題へ'),
              ),
            ],
          ],
        ),
        if (_showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: -1.5708, // 真上
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 16,
                gravity: 0.4,
                shouldLoop: false,
                colors: const [
                  AppColors.accent,
                  AppColors.reward,
                  AppColors.info,
                  AppColors.warmAccent,
                ],
              ),
            ),
          ),
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
