import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/application/progress_providers.dart';
import '../../../quiz/domain/learning_stage.dart';

const _stageColors = {
  LearningStage.basics: AppColors.accent,
  LearningStage.preflop: AppColors.reward,
  LearningStage.boardReading: AppColors.info,
  LearningStage.math: AppColors.rangeCall,
  LearningStage.advanced: AppColors.rangeThreeBet,
};

/// 全11カテゴリを5ステージに束ねた学習プラン。
///
/// 進捗バーは「問題数の進捗（こなした問題 / 総問題）」で表示し、正答率はテキスト。
/// 問題数の進捗 × 正解率 = 100%（＝全問を正解済み）になったステージは Clear。
class LearningRoadmapCard extends ConsumerWidget {
  const LearningRoadmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider);
    final current = _currentStage(progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '学習プラン',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        for (var i = 0; i < LearningStage.values.length; i++)
          _StageRow(
            index: i + 1,
            progress: progress.of(LearningStage.values[i]),
            isCurrent: LearningStage.values[i] == current,
            showDivider: i > 0,
          ),
        const _RangeDrillRow(),
      ],
    );
  }

  /// 現在地 = まだ Clear していない、最初のステージ。
  LearningStage _currentStage(LearningProgress progress) {
    for (final stage in LearningStage.values) {
      if (!progress.of(stage).cleared) return stage;
    }
    return LearningStage.values.last;
  }
}

/// 学習プランの最後に置く「レンジ表暗記」への導線（クイズの正答率とは別枠）。
class _RangeDrillRow extends StatelessWidget {
  const _RangeDrillRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.rangeDrill),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.rangeThreeBet,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'レンジ表暗記',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '表を隠して、ハンドごとのアクションを当てる',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.index,
    required this.progress,
    required this.isCurrent,
    required this.showDivider,
  });

  final int index;
  final StageProgress progress;
  final bool isCurrent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final stage = progress.stage;
    final color = _stageColors[stage] ?? AppColors.accent;
    final cleared = progress.cleared;

    return Container(
      padding: EdgeInsets.only(top: showDivider ? AppSpacing.md : 4),
      margin: EdgeInsets.only(top: showDivider ? AppSpacing.md : 0),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cleared ? AppColors.accent : color,
              shape: BoxShape.circle,
            ),
            child: cleared
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stage.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (cleared) ...[
                      const SizedBox(width: 6),
                      _Pill(text: 'Clear', color: AppColors.accent),
                    ] else if (isCurrent) ...[
                      const SizedBox(width: 6),
                      _Pill(text: '現在地', color: AppColors.info),
                    ],
                    const Spacer(),
                    Text(
                      progress.attempted == 0
                          ? '未着手'
                          : '${progress.attempted}/${progress.total}問・正答率 ${(progress.accuracy * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (stage.categoryLabels != stage.label) ...[
                  const SizedBox(height: 3),
                  Text(
                    stage.categoryLabels,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
