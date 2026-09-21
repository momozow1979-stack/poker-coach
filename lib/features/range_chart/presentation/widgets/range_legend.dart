import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/range_action.dart';

/// 凡例。色だけでなく記号も併記する（仕様書 10 のアクセシビリティ要件）。
class RangeLegend extends StatelessWidget {
  const RangeLegend({super.key, required this.actions});

  final List<RangeAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            for (final action in actions)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: action == RangeAction.fold
                          ? AppColors.rangeFold
                          : action.color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      action.symbol,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: action == RangeAction.fold
                            ? AppColors.textMuted
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (actions.contains(RangeAction.mixed)) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Mixed（M）= 1つのハンドで複数のアクションを一定の割合で混ぜる手。'
            'マスをタップすると内訳（例: レイズ60% / コール40%）が見られます。',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
