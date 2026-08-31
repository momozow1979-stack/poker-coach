import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/playing_card_view.dart';
import '../../../../shared/widgets/score_ring.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../domain/trainer_scenario.dart';
import '../../domain/trainer_session.dart';
import 'verdict_style.dart';

/// ハンドを打ち終わったあとの総括。
class TrainerSummaryView extends StatelessWidget {
  const TrainerSummaryView({
    super.key,
    required this.session,
    required this.onRestart,
    required this.onBackToList,
  });

  final TrainerSession session;
  final VoidCallback onRestart;
  final VoidCallback onBackToList;

  @override
  Widget build(BuildContext context) {
    final scenario = session.scenario;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScoreRing(
                    score: session.achievement,
                    size: 96,
                    caption: '達成度',
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ハンドおつかれさまでした',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          scenario.title,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PlayingCardRow(cards: scenario.heroCards, width: 32),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: '最善',
                      value: '${session.countOf(TrainerVerdict.best)}',
                      unit: '/ ${session.answeredCount}',
                      valueColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      label: '悪くない',
                      value: '${session.countOf(TrainerVerdict.reasonable)}',
                      valueColor: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      label: '避けたい',
                      value: '${session.countOf(TrainerVerdict.mistake)}',
                      valueColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '「最善」を2点、「悪くない」を1点として数えた達成度です。'
                'ポーカーの期待値ではなく、このアプリの採点です。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (session.endedEarly) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceHigh,
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'フォールドを選んだので、ここでハンドは終わりです。'
                    'この先を見たい場合は、もう一度挑戦してみてください。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _Heading('ストリート別の振り返り'),
        const SizedBox(height: AppSpacing.md),
        for (final entry in session.review) ...[
          _ReviewRow(spot: entry.spot, option: entry.option),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _Heading('このハンドの学び'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderColor: AppColors.accent.withValues(alpha: 0.35),
          child: Text(
            scenario.takeaway,
            style: const TextStyle(
              fontSize: 14,
              height: 1.85,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('もう一度このハンドを打つ'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onBackToList,
          icon: const Icon(Icons.list_rounded),
          label: const Text('別のハンドを選ぶ'),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.spot, required this.option});

  final TrainerSpot spot;
  final TrainerOption option;

  @override
  Widget build(BuildContext context) {
    final style = verdictStyle(option.verdict);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(style.icon, size: 18, color: style.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.street.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  option.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            option.verdict.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}
