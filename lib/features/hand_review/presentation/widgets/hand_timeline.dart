import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/street.dart';
import '../../../../shared/widgets/playing_card_view.dart';
import '../../domain/hand_review_input.dart';

/// ここまでに入力した内容を、ストリート順に並べて見せる。
class HandTimeline extends StatelessWidget {
  const HandTimeline({
    super.key,
    required this.input,
    required this.villainLabel,
    required this.onUndo,
  });

  final HandReviewInput input;
  final String villainLabel;

  /// 直前の入力を1つ取り消す。何も無ければ null。
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final streets = [
      for (final street in Street.values)
        if (input.actionsOf(street).isNotEmpty ||
            input.boardOf(street).isNotEmpty)
          street,
    ];

    if (streets.isEmpty) {
      return const Text(
        'ここに入力した流れが並びます。',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final street in streets) ...[
          _StreetRow(
            street: street,
            board: input.boardOf(street),
            actions: input.actionsOf(street),
            villainLabel: villainLabel,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (onUndo != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('1つ戻す'),
            ),
          ),
      ],
    );
  }
}

class _StreetRow extends StatelessWidget {
  const _StreetRow({
    required this.street,
    required this.board,
    required this.actions,
    required this.villainLabel,
  });

  final Street street;
  final List<PlayingCard> board;
  final List<HandAction> actions;
  final String villainLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              street.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
            if (board.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              PlayingCardRow(cards: board, width: 26, spacing: AppSpacing.xs),
            ],
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final action in actions)
                _ActionPill(action: action, villainLabel: villainLabel),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.action, required this.villainLabel});

  final HandAction action;
  final String villainLabel;

  @override
  Widget build(BuildContext context) {
    final color = action.isHero ? AppColors.accent : AppColors.info;
    final who = action.isHero ? 'あなた' : villainLabel;
    final size = action.sizeBb;
    final label = size == null
        ? '$who ${action.action.description}'
        : '$who ${action.action.description} ${HandAction.formatBb(size)}BB';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
