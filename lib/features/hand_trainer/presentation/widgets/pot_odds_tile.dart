import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/trainer_scenario.dart';
import 'trainer_format.dart';

/// 相手のベットに対する必要勝率。
///
/// ここに出す数値は割り算で確定するものだけ。
/// ソルバーの頻度や EV のような、根拠を示せない数値は扱わない。
class PotOddsTile extends StatelessWidget {
  const PotOddsTile({super.key, required this.spot});

  final TrainerSpot spot;

  @override
  Widget build(BuildContext context) {
    final equity = spot.requiredEquity;
    if (equity == null) return const SizedBox.shrink();

    final winnable = spot.potBb + spot.toCallBb;
    final percent = (equity * 100).round();

    return AppCard(
      color: AppColors.info.withValues(alpha: 0.1),
      borderColor: AppColors.info.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_rounded,
                size: 16,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'この場面のポットオッズ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${formatBb(spot.toCallBb)}BB 払うと、'
            'ポットは ${formatBb(winnable)}BB になります。',
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '必要な勝率',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '約 $percent%',
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '払う額 ÷ 払ったあとのポット = '
            '${formatBb(spot.toCallBb)} ÷ ${formatBb(winnable)} の割り算です。'
            'これを超えて勝てそうならコールが得になります。',
            style: const TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
