import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../practice_table/presentation/widgets/practice_explanation_view.dart'
    show practiceVerdictColor;
import '../../../range_chart/infrastructure/mock_range_repository.dart';
import '../../domain/hand_review_input.dart';
import '../../domain/manual_hand_grader.dart';

/// 手入力したハンドの、計算で確かめられる判断の採点。重い計算（勝率の
/// 数え上げ）があるので、画面を出してから非同期に計算する。
final manualHandGradesProvider = FutureProvider.autoDispose
    .family<List<ManualDecisionGrade>, HandReviewInput>((ref, input) async {
      await Future<void>.delayed(Duration.zero);
      return const ManualHandGrader(ranges: MockRangeRepository()).grade(input);
    });

/// レビュー結果に出す「計算で確かめた判断（○△×）」。
class ManualGradesCard extends ConsumerWidget {
  const ManualGradesCard({super.key, required this.input});

  final HandReviewInput input;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(manualHandGradesProvider(input));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '計算で確かめた判断（○△×）',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'レンジ表と、ポットオッズ・勝率の計算で確かめられる判断だけを採点しています。',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          grades.when(
            loading: () => const LinearProgressIndicator(minHeight: 6),
            error: (_, _) => const Text(
              '採点できませんでした',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            data: (value) => value.isEmpty
                ? const Text(
                    '採点できる判断がありませんでした。',
                    style: TextStyle(fontSize: 13),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final grade in value) _GradeTile(grade: grade),
                      if (value.any(
                        (g) => g.street.index > 0 && g.verdict != null,
                      ))
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '※ ${ManualHandGrader.villainBetAssumption}',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.textMuted,
                            ),
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

class _GradeTile extends StatelessWidget {
  const _GradeTile({required this.grade});

  final ManualDecisionGrade grade;

  @override
  Widget build(BuildContext context) {
    final verdict = grade.verdict;
    final color = verdict == null
        ? AppColors.textMuted
        : practiceVerdictColor(verdict);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          leading: Text(
            verdict?.symbol ?? '－',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          title: Text(
            '${grade.street.label}　${grade.actionLabel}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            grade.headline,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reason in grade.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  reason,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            for (final (label, value) in grade.numbers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (grade.ifChanged != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'こうなら答えが変わる: ${grade.ifChanged}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.info,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
