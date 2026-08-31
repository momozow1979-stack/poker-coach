import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/playing_card_view.dart';
import '../../../../shared/widgets/poker_table_view.dart';
import '../../domain/quiz.dart';

/// クイズのゲーム状況を表示するカード。
class QuizSituationCard extends StatelessWidget {
  const QuizSituationCard({super.key, required this.situation});

  final QuizSituation situation;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(text: situation.tableType.label),
              _MetaPill(text: situation.blindsLabel),
              _MetaPill(text: '${situation.effectiveStackBb.toInt()}BB'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _VillainProfile(text: situation.villainProfile),
          const SizedBox(height: AppSpacing.md),
          PokerTableView(
            tableType: situation.tableType,
            heroPosition: situation.heroPosition,
            villainPosition: situation.villainPosition,
            potLabel: 'Pot ${_formatBb(situation.potBb)}BB',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('あなたのハンド'),
          const SizedBox(height: AppSpacing.sm),
          PlayingCardRow(
            cards: situation.heroCards,
            width: 44,
            dealAnimation: true,
          ),
          if (situation.board.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _FieldLabel('ボード（${situation.street.label}）'),
            const SizedBox(height: AppSpacing.sm),
            PlayingCardRow(
              cards: situation.board,
              width: 38,
              dealAnimation: true,
              dealDelay: Duration(
                milliseconds: 90 * situation.heroCards.length,
              ),
            ),
          ],
          if (situation.actionHistory.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('アクション履歴'),
            const SizedBox(height: AppSpacing.sm),
            for (final line in situation.actionHistory)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: AppSpacing.sm),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatBb(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// 相手のタイプ。前提が変われば正解も変わるため、状況の一部として明示する。
class _VillainProfile extends StatelessWidget {
  const _VillainProfile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1, right: AppSpacing.xs),
          child: Icon(Icons.person_outline, size: 14, color: AppColors.info),
        ),
        Expanded(
          child: Text(
            '相手: $text',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _LegendDot(color: AppColors.accent, label: 'あなた'),
        const SizedBox(width: AppSpacing.lg),
        const _LegendDot(color: AppColors.info, label: '相手'),
        const Spacer(),
        const Text(
          'D = ディーラーボタン',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
