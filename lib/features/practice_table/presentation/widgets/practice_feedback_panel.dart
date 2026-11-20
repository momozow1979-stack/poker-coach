import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/playing_card.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/practice_providers.dart';
import '../../domain/grading/decision_grade.dart';
import '../../domain/grading/grade_explainer.dart';

/// ○△× ごとの色。色だけに頼らないよう、必ず記号も一緒に出す。
Color practiceVerdictColor(PracticeVerdict verdict) => switch (verdict) {
  PracticeVerdict.good => AppColors.success,
  PracticeVerdict.close => AppColors.warning,
  PracticeVerdict.bad => AppColors.danger,
};

/// 初心者モードで、アクションを選んだ直後に出す判定と理由。
///
/// まだアクションは確定していない。「やり直す」で同じ場面に戻って
/// 別のアクションを試せ、「このまま進む」で選んだとおりに進める。
class PracticeFeedbackPanel extends StatelessWidget {
  const PracticeFeedbackPanel({
    super.key,
    required this.feedback,
    required this.heroCards,
    required this.board,
    required this.onRetry,
    required this.onConfirm,
  });

  final PracticeFeedback feedback;

  /// パネルがテーブルを覆っても、手札とボードを見ながら読めるように出す。
  final List<PlayingCard> heroCards;
  final List<PlayingCard> board;

  final VoidCallback onRetry;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final explanation = feedback.explanation;
    final color = practiceVerdictColor(explanation.verdict);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VerdictHeader(
                    explanation: explanation,
                    chosenLabel: feedback.chosen.option.label,
                    color: color,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'あなたの手札 ${_cardsText(heroCards)}'
                    '${board.isEmpty ? '' : '　ボード ${_cardsText(board)}'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final reason in explanation.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                  if (explanation.betterChoice != null)
                    _Callout(
                      icon: Icons.flag_rounded,
                      color: AppColors.accent,
                      text: explanation.betterChoice!,
                    ),
                  if (explanation.ifChanged != null)
                    _Callout(
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.info,
                      label: 'こうなら答えが変わる',
                      text: explanation.ifChanged!,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _Numbers(numbers: explanation.numbers),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    explanation.note,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('やり直す'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('このまま進む'),
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

String _cardsText(List<PlayingCard> cards) =>
    cards.map((card) => '${card.rank.symbol}${card.suit.symbol}').join(' ');

class _VerdictHeader extends StatelessWidget {
  const _VerdictHeader({
    required this.explanation,
    required this.chosenLabel,
    required this.color,
  });

  final PracticeGradeExplanation explanation;
  final String chosenLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          Text(
            explanation.verdict.symbol,
            style: TextStyle(
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  explanation.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'あなたの選択: $chosenLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.color,
    required this.text,
    this.label,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.numbers});

  final List<GradeNumber> numbers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '根拠の数字',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final number in numbers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        number.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      number.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (number.note != null)
                  Text(
                    number.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
