import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/playing_card.dart';
import '../../application/practice_providers.dart';
import 'practice_explanation_view.dart';

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
  final List<PlayingCard> heroCards;
  final List<PlayingCard> board;
  final VoidCallback onRetry;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
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
              child: PracticeExplanationView(
                explanation: feedback.explanation,
                chosenLabel: feedback.chosen.option.label,
                reasonGrade: feedback.reasonGrade,
                heroCards: heroCards,
                board: board,
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
