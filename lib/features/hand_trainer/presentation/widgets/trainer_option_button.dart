import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/trainer_scenario.dart';
import 'verdict_style.dart';

/// 意思決定トレーナーの選択肢ボタン。
///
/// 回答前はどれも同じ見た目にする。
/// 回答後は、選んだものと最善のものが評価つきで分かるようにする。
class TrainerOptionButton extends StatelessWidget {
  const TrainerOptionButton({
    super.key,
    required this.option,
    required this.isRevealed,
    required this.isSelected,
    required this.onTap,
  });

  final TrainerOption option;
  final bool isRevealed;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = verdictStyle(option.verdict);
    // 回答後は、選んだものと最善のものだけ色を付ける。
    // 4つ全部を塗ると、どれが自分の選択か分からなくなる。
    final highlighted =
        isRevealed && (isSelected || option.verdict == TrainerVerdict.best);
    final borderColor = highlighted ? style.color : AppColors.border;
    final radius = BorderRadius.circular(AppSpacing.radiusSm + 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: highlighted
            ? style.color.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: isRevealed ? null : onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (isRevealed && isSelected) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'あなたの選択',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (highlighted) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(style.icon, size: 18, color: style.color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    option.verdict.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: style.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
