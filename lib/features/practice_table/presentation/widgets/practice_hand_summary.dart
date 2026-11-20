import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/practice_providers.dart';
import '../../domain/grading/decision_grade.dart';
import '../../domain/grading/hand_reviewer.dart';
import '../../domain/practice_hand_record.dart';
import 'practice_explanation_view.dart';

/// ハンドが終わったら出す総合評価。
///
/// 初心者モードでも、通してプレイするモードでも、ハンドの最後に
/// 「何点だったか・どの判断が良かったか・理由は合っていたか」を
/// 一覧で見せる。各判断の詳しい解説は「1手ずつ振り返る」で見る。
class PracticeHandSummary extends ConsumerWidget {
  const PracticeHandSummary({super.key, required this.record});

  final PracticeHandRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(practiceHandReviewProvider(record));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: review.when(
        loading: () => const _Loading(),
        error: (_, _) => const Text(
          'このハンドは採点できませんでした',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        // 採点が終わって中身が出たら、画面の外でも見える位置まで送る。
        data: (value) =>
            _RevealOnMount(child: PracticeHandSummaryBody(review: value)),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'このハンドを採点しています…',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(minHeight: 6),
      ],
    );
  }
}

/// 点数・内訳・判断ごとの一覧（振り返り画面の上部でも使う）。
class PracticeHandSummaryBody extends StatelessWidget {
  const PracticeHandSummaryBody({
    super.key,
    required this.review,
    this.currentEventIndex,
    this.onTapDecision,
  });

  final PracticeHandReview review;

  /// 振り返り画面で、いま見ている判断（強調表示する）。
  final int? currentEventIndex;

  /// 判断を押したとき（振り返り画面で、その場面へ移動する）。
  final ValueChanged<ReviewedDecision>? onTapDecision;

  @override
  Widget build(BuildContext context) {
    final score = review.score;
    final total = score.total;
    final mistake = review.biggestMistake;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'このハンドの評価',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (total != null) ...[
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: _scoreColor(total),
                ),
              ),
              const Text(
                ' / 100点',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          score.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: total == null ? AppColors.textSecondary : _scoreColor(total),
          ),
        ),
        if (review.decisions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'アクション ${score.actionPoints}/${score.actionMax}点'
            '（○2・△1・×0）'
            '${score.reasonAnswered == 0 ? '' : '　理由 ${score.reasonCorrect}/${score.reasonAnswered}点'}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final decision in review.decisions)
            _DecisionRow(
              decision: decision,
              selected: decision.eventIndex == currentEventIndex,
              onTap: onTapDecision == null
                  ? null
                  : () => onTapDecision!(decision),
            ),
        ],
        if (mistake != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '一番の改善点: ${mistake.street.label}の${mistake.chosen.option.label}'
            '${mistake.chosen.lossBb == null ? '' : '（${formatBb(_roundQuarter(mistake.chosen.lossBb!))}BB 損）'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
        if (review.ungradedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '採点できなかった判断: ${review.ungradedCount}件'
              '（以前の打ち方の AI と対戦した記録など）',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  static double _roundQuarter(double value) => (value * 4).round() / 4;

  static Color _scoreColor(int total) {
    if (total >= 70) return AppColors.success;
    if (total >= 50) return AppColors.warning;
    return AppColors.danger;
  }
}

/// 判断 1 行: 「○ フロップ ベット 3BB　理由 ○」。
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.decision,
    required this.selected,
    required this.onTap,
  });

  final ReviewedDecision decision;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final verdict = decision.chosen.verdict;
    final color = practiceVerdictColor(verdict);
    final reason = decision.reasonGrade;

    final row = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.14) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.7) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              verdict.symbol,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${decision.street.label}　${decision.chosen.option.label}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          if (reason != null)
            Text(
              '理由 ${reason.verdict.symbol}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: reasonVerdictColor(reason.verdict),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label:
          '${verdict.symbol} ${decision.street.label} '
          '${decision.chosen.option.label}'
          '${reason == null ? '' : ' 理由${reason.verdict.symbol}'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// 出てきたときに、画面の外にあれば見える位置までスクロールする
/// （ハンドが終わったら、総合評価を探さなくても目に入るように）。
class _RevealOnMount extends StatefulWidget {
  const _RevealOnMount({required this.child});

  final Widget child;

  @override
  State<_RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<_RevealOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
