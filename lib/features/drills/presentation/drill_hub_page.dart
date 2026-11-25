import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/learning_mode_bar.dart';

/// 学習タブの「ドリル」: 短い問題をテンポよく繰り返す練習の入口。
class DrillHubPage extends StatelessWidget {
  const DrillHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ドリル')),
      body: SafeArea(
        child: Column(
          children: [
            const LearningModeBar(current: LearningMode.drill),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  for (final drill in DrillKind.values) ...[
                    _DrillCard(drill: drill),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ドリルの種類。新しいドリルはここに足す。
enum DrillKind {
  preflop(
    title: 'プリフロップ連続ドリル',
    description:
        'ランダムな席・手札で「降りる・コール・レイズ・3ベット」を即答。'
        '境目の手を多めに出します。',
    icon: Icons.bolt_rounded,
    route: AppRoutes.preflopDrill,
  ),
  equity(
    title: '勝率クイズ',
    description:
        '自分と相手の手札・ボードを見て、リバーまでの勝率を当てる。'
        '答えは全通りを数えた正確な値。アウツの数え方も身に付きます。',
    icon: Icons.percent_rounded,
    route: AppRoutes.equityQuiz,
  ),
  bluff(
    title: 'ブラフ練習',
    description:
        '相手がチェックしてきた、自分の手が弱い場面。そもそもブラフするか、'
        'するならいくら賭けるかを選び、相手が降りる割合と必要な割合で答え合わせ。',
    icon: Icons.theater_comedy_rounded,
    route: AppRoutes.bluffDrill,
  );

  const DrillKind({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({required this.drill});

  final DrillKind drill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(drill.route),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(drill.icon, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drill.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  drill.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
