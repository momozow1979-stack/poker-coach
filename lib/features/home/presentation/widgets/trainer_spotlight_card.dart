import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../hand_trainer/domain/trainer_scenario.dart';

/// ホームの「今日の重点問題」と横並びになる、ウォークスルーへの入り口。
///
/// 「ウォークスルーピックアップ」という名前で、日付だけを基準に
/// 全シナリオを順番に回している選び方であることを見せる
/// （苦手分野には未対応 — [todayScenarioProvider] 参照）。
/// [scenario.goal] を添えることで、このハンドで何を判断させたいのかを
/// タイトルだけでは伝わらない部分まで一言で示す。
class TrainerSpotlightCard extends StatelessWidget {
  const TrainerSpotlightCard({
    super.key,
    required this.scenario,
    required this.onTap,
    required this.onBrowseAll,
  });

  final TrainerScenario scenario;
  final VoidCallback onTap;

  /// 「他のハンドを選ぶ」で一覧（ポジション絞り込み含む）へ。
  final VoidCallback onBrowseAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentDark,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accentDark, AppColors.accent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ウォークスルーピックアップ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFFD9F2E1),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  scenario.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scenario.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.accentDark,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('進める', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: onBrowseAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '他のハンドを選ぶ',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
