import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../domain/quiz.dart';
import 'quiz_choice_button.dart';
import 'quiz_explanation_view.dart';
import 'quiz_situation_card.dart';

/// 1問ぶんの出題〜解説の表示。
///
/// 「今日の10問」（[QuizPage]）と、カテゴリを絞った復習
/// （`CategoryQuizPage`）の両方から使う共通部品。
/// セッションの進行（何問目か・どこまで答えたか）はここでは持たず、
/// 呼び出し元から渡された1問ぶんの状態だけを描画する。
class QuizSessionView extends StatefulWidget {
  const QuizSessionView({
    super.key,
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
  State<QuizSessionView> createState() => _QuizSessionViewState();
}

class _QuizSessionViewState extends State<QuizSessionView> {
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
  void didUpdateWidget(covariant QuizSessionView oldWidget) {
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
