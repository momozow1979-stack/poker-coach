import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../quiz/domain/daily_quiz_session.dart';

/// 「今日の10問」への導線。
///
/// 看板はハンドトレーナー（ウォークスルー）側に譲り、こちらは座学への
/// 軽い入り口として、控えめな1行カードにしている。
class DailyQuizCard extends StatelessWidget {
  const DailyQuizCard({
    super.key,
    required this.session,
    required this.onStart,
  });

  final DailyQuizSession session;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isFinished = session.isFinished;

    return AppCard(
      onTap: onStart,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('📖', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '座学 ・ 今日の10問',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      isFinished
                          ? '正解 ${session.correctCount}/${session.totalCount}'
                          : '${session.answeredCount} / ${session.totalCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceHigh,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
