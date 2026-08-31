import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/playing_card.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/playing_card_view.dart';
import '../../../../shared/widgets/poker_table_view.dart';
import '../../domain/trainer_scenario.dart';
import 'trainer_format.dart';

/// 現在の卓の様子。図で状況をつかめるようにする。
class TrainerStageCard extends StatelessWidget {
  const TrainerStageCard({
    super.key,
    required this.scenario,
    required this.spot,
    required this.board,
  });

  final TrainerScenario scenario;
  final TrainerSpot spot;

  /// このストリートまでに開いているボード。
  final List<PlayingCard> board;

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
              _Pill(text: scenario.tableType.label),
              _Pill(text: scenario.blindsLabel),
              _Pill(text: scenario.positionLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1, right: AppSpacing.xs),
                child: Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.info,
                ),
              ),
              Expanded(
                child: Text(
                  '相手: ${scenario.villainProfile}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PokerTableView(
            tableType: scenario.tableType,
            heroPosition: scenario.heroPosition,
            villainPosition: scenario.villainPosition,
            potLabel: 'ポット ${formatBb(spot.potBb)}BB',
            height: 132,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
          const SizedBox(height: AppSpacing.lg),
          // 手札とボードは横に並べる。縦に積むと選択肢まで遠くなり、
          // 「その場で判断する」体験が損なわれる。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('あなたのハンド'),
                  const SizedBox(height: AppSpacing.sm),
                  PlayingCardRow(
                    cards: scenario.heroCards,
                    width: 40,
                    spacing: AppSpacing.xs,
                    dealAnimation: true,
                  ),
                ],
              ),
              if (board.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('ボード（${spot.street.label}）'),
                      const SizedBox(height: AppSpacing.sm),
                      PlayingCardRow(
                        cards: board,
                        width: 34,
                        spacing: AppSpacing.xs,
                        dealAnimation: true,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (spot.actionHistory.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('ここまでの流れ'),
            const SizedBox(height: AppSpacing.sm),
            for (final line in spot.actionHistory)
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

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
