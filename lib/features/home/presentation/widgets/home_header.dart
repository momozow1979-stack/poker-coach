import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/labeled_progress_bar.dart';
import '../../../profile/domain/learning_stats.dart';
import '../../../profile/domain/user_profile.dart';

/// ホーム上部の挨拶・レベル・連続学習日数。
///
/// グラデーションの「主役」面にして、フラットなカードが並ぶ中で
/// 一番最初に目に入る場所だとわかるようにする。
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.profile, required this.stats});

  final UserProfile profile;
  final LearningStats stats;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'こんばんは';
    if (hour < 11) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardGlow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting、${profile.displayName}さん',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Lv.${stats.level}  ${profile.pokerLevel.label}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _StreakBadge(days: stats.streakDays),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LabeledProgressBar(
            label: '次のレベルまで',
            value: stats.levelProgress,
            trailingText: '${(stats.levelProgress * 100).round()}%',
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.rewardGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppColors.cardGlow(color: AppColors.rewardDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: Color(0xFF3A1E00),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$days日連続',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A1E00),
            ),
          ),
        ],
      ),
    );
  }
}
