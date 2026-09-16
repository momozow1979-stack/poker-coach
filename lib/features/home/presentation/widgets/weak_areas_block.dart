import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../quiz/domain/quiz_category.dart';

/// 「苦手分野」（未検出のうちは「学びたい分野」）のチップ一覧。
///
/// [LearningRoadmapCard] と1枚のカードにまとめて使う想定。
class WeakAreasBlock extends StatelessWidget {
  const WeakAreasBlock({
    super.key,
    required this.categories,
    required this.usingFallback,
    required this.onCategoryTap,
  });

  /// 苦手分野が未検出のときは、オンボーディングで選んだ「学びたい分野」。
  final List<QuizCategory> categories;
  final bool usingFallback;
  final ValueChanged<QuizCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          usingFallback && categories.isNotEmpty ? '学びたい分野' : '苦手分野',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (categories.isEmpty)
          const Text(
            '各カテゴリ3問以上で判定されます',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in categories)
                TagChip(
                  label: category.label,
                  color: usingFallback ? AppColors.info : AppColors.danger,
                  icon: usingFallback
                      ? Icons.school_rounded
                      : Icons.priority_high_rounded,
                  onTap: () => onCategoryTap(category),
                ),
            ],
          ),
      ],
    );
  }
}
