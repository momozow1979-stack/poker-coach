import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../application/consolidated_range.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_spot.dart';

/// プリフロップレンジ表（ポジション別に色分けした集約表示）。
///
/// ポジションを1つずつ切り替えるのではなく、1枚の表で「どのハンドを
/// どのポジションから取るか」を色で見せる。オープンは後ろの席ほど広がるので、
/// 一番タイトな席の色で塗る＝色が広がるほど後ろの席まで含む、と読める。
class RangePage extends ConsumerStatefulWidget {
  const RangePage({super.key});

  @override
  ConsumerState<RangePage> createState() => _RangePageState();
}

class _RangePageState extends ConsumerState<RangePage> {
  RangeSituation _situation = RangeSituation.openRaise;
  RangeAction _vsAction = RangeAction.call;

  RangeAction get _action =>
      _situation == RangeSituation.openRaise ? RangeAction.raise : _vsAction;

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(selectedTableTypeProvider);
    final repo = ref.read(rangeRepositoryProvider);
    final heatmap = consolidate(repo, table, _situation, _action);
    final positions = positionsWithChart(repo, table, _situation);

    return Scaffold(
      appBar: AppBar(title: const Text('レンジ表')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            ChoiceChipGroup<TableType>(
              values: TableType.values,
              selected: table,
              labelBuilder: (v) => v.label,
              onSelected: ref.read(selectedTableTypeProvider.notifier).select,
            ),
            const SizedBox(height: AppSpacing.md),
            ChoiceChipGroup<RangeSituation>(
              values: const [RangeSituation.openRaise, RangeSituation.vsOpen],
              selected: _situation,
              labelBuilder: (v) =>
                  v == RangeSituation.openRaise ? 'オープンする' : 'オープンに対応する',
              onSelected: (v) => setState(() => _situation = v),
            ),
            if (_situation == RangeSituation.vsOpen) ...[
              const SizedBox(height: AppSpacing.md),
              ChoiceChipGroup<RangeAction>(
                values: const [RangeAction.call, RangeAction.threeBet],
                selected: _vsAction,
                labelBuilder: (v) => v == RangeAction.call ? 'コール' : '3ベット',
                onSelected: (v) => setState(() => _vsAction = v),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Text(
                _situation == RangeSituation.openRaise
                    ? '各ハンドを「オープンする一番早い席」の色で表示しています。'
                          '色が濃い（前の席）ほどタイト、後ろの席ほどレンジが広がります。'
                    : 'オープンに対して${_vsAction == RangeAction.call ? "コール" : "3ベット"}する'
                          '一番早い席の色で表示しています。',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(aspectRatio: 1, child: _grid(heatmap)),
            const SizedBox(height: AppSpacing.lg),
            _legend(positions),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'マスをタップすると、そのハンドをどの席でオープン/コール/3ベットするかが見られます。',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(Map<StartingHand, Position> heatmap) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(
                    child: _cell(StartingHand.fromGrid(row, col), heatmap),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, Map<StartingHand, Position> heatmap) {
    final pos = heatmap[hand];
    final bg = pos == null
        ? AppColors.rangeFold
        : positionColor(pos).withValues(alpha: 0.85);
    final fg = pos == null ? AppColors.textMuted : Colors.white;
    return GestureDetector(
      onTap: () => _showHandPositions(hand),
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              hand.code,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(List<Position> positions) {
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          for (final p in positions)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: positionColor(p).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  p.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.rangeFold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Text(
                'フォールド',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHandPositions(StartingHand hand) {
    final table = ref.read(selectedTableTypeProvider);
    final repo = ref.read(rangeRepositoryProvider);
    final summary = handPositionSummary(repo, table, hand);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hand.code}（${hand.description}）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            _summaryLine('オープンする席', summary.opens),
            _summaryLine('オープンにコールする席', summary.calls),
            _summaryLine('オープンに3ベットする席', summary.threeBets),
            if (summary.opens.isEmpty &&
                summary.calls.isEmpty &&
                summary.threeBets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'どのレンジにも入っていません（基本フォールド）。',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, List<Position> positions) {
    if (positions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            TextSpan(text: positions.map((p) => p.label).join('・')),
          ],
        ),
      ),
    );
  }
}
