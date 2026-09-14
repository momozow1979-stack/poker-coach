import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/labeled_progress_bar.dart';
import '../../../quiz/domain/daily_quiz_session.dart';

/// 「今日の10問」への導線。
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
    final isStarted = session.answeredCount > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '今日の10問',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${session.answeredCount} / ${session.totalCount}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LabeledProgressBar(
            label: isFinished
                ? '正解 ${session.correctCount} 問 ・ 正答率 ${(session.accuracy * 100).round()}%'
                : '毎日10分で強くなる',
            value: session.progress,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: Icon(
                isFinished
                    ? Icons.replay_rounded
                    : (isStarted
                          ? Icons.play_arrow_rounded
                          : Icons.play_circle_fill_rounded),
              ),
              label: Text(
                isFinished ? 'もう一度解く' : (isStarted ? '続きから解く' : '今日の10問を始める'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
