import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../quiz/domain/daily_quiz_session.dart';
import '../../../quiz/domain/learning_stage.dart';

/// ステージごとに割り当てる色。[LearningRoadmapCard] の配色と揃えている。
const _stageDotColors = {
  LearningStage.basics: Colors.white,
  LearningStage.preflop: AppColors.reward,
  LearningStage.boardReading: Color(0xFF7CC4FF),
  LearningStage.math: Color(0xFF7CE8A0),
  LearningStage.advanced: Color(0xFFC9B8F5),
};

/// ホームの「今日の重点問題」への入り口。
///
/// 苦手分野から選ばれた10問であることが伝わるよう、
/// 学習プランのどのステージが何問ずつ入っているかを内訳で見せる。
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
    final counts = <LearningStage, int>{};
    for (final quiz in session.quizzes) {
      final stage = LearningStage.forCategory(quiz.category);
      counts[stage] = (counts[stage] ?? 0) + 1;
    }

    return Material(
      color: AppColors.accentDark,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
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
                  '今日の重点問題',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFFD9F2E1),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: isFinished
                            ? '${session.correctCount}'
                            : '${session.answeredCount}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: '/${session.totalCount}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation(AppColors.reward),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final stage in LearningStage.values)
                  if (counts[stage] case final count? when count > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _stageDotColors[stage],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '${stage.label} $count問',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
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
