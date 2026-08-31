import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/trainer_scenario.dart';
import 'verdict_style.dart';

/// 選んだ直後にその場で出す解説。
///
/// 最後にまとめて見せるのではなく、選択と解説を近づけることで
/// 「なぜそうなるのか」が記憶に残りやすくなる。
class TrainerFeedbackCard extends StatelessWidget {
  const TrainerFeedbackCard({
    super.key,
    required this.spot,
    required this.selected,
  });

  final TrainerSpot spot;
  final TrainerOption selected;

  /// 選んだものが最善でなかったときに見せる、最善の選択。
  TrainerOption? get _best {
    if (selected.verdict == TrainerVerdict.best) return null;
    for (final option in spot.options) {
      if (option.verdict == TrainerVerdict.best) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style = verdictStyle(selected.verdict);
    final best = _best;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: style.color.withValues(alpha: 0.1),
          borderColor: style.color.withValues(alpha: 0.4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(style.icon, size: 28, color: style.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.verdict.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: style.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.verdict.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Block(
          icon: Icons.lightbulb_outline_rounded,
          title: 'なぜそうなるか',
          body: selected.reason,
          accent: AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Block(
          icon: Icons.swap_horiz_rounded,
          title: '何が変われば答えが変わるか',
          body: selected.ifChanged,
          accent: AppColors.info,
        ),
        if (best != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _Block(
            icon: Icons.star_rounded,
            title: 'この場面の最善は「${best.label}」',
            body: best.reason,
            accent: AppColors.warning,
          ),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.75,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
