import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../hand_trainer/domain/trainer_scenario.dart';

/// ホーム画面の看板。ハンドトレーナー（ウォークスルー）への入り口。
///
/// 「プレイして、あとで振り返る」のではなく、各ストリートでその場で
/// 考え方を支えるウォークスルーこそがこのアプリの本体、という方針に
/// 合わせて、今日の10問より上・より大きく置く。
class TrainerSpotlightCard extends StatelessWidget {
  const TrainerSpotlightCard({
    super.key,
    required this.scenario,
    required this.onTap,
  });

  final TrainerScenario scenario;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CE8A0),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7CE8A0)
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      '今日のウォークスルー',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Color(0xFFD9F2E1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  scenario.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  scenario.goal,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.8,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Tag(
                      scenario.difficulty.label,
                      background: AppColors.reward,
                      foreground: const Color(0xFF3A1E00),
                    ),
                    _Tag(scenario.positionLabel),
                    _Tag(scenario.boardStyle.label),
                    _Tag('🎴 ${scenario.spotCount}つの判断'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.accentDark,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('このハンドを進める'),
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

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground ?? Colors.white,
        ),
      ),
    );
  }
}
