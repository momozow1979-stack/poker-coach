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

/// 3ベットを表す共通色（席で分けず1色）。
const Color _threeBetColor = Color(0xFF1F2937);

/// プリフロップレンジ表（6MAX・ポジション別色分けの集約表示）。
///
/// ポジションを1つずつ切り替えず、1枚の表に集約。各ハンドを「そのアクションを
/// 取る一番レンジが狭い席の色」で塗る（色が広がるほど後ろの席まで含む）。
/// vsオープンは、コール＝席の色 / 3ベット＝共通の黒 / フォールド＝灰。
class RangePage extends ConsumerStatefulWidget {
  const RangePage({super.key});

  @override
  ConsumerState<RangePage> createState() => _RangePageState();
}

class _RangePageState extends ConsumerState<RangePage> {
  // 覚えやすさ優先で 6MAX のみ扱う（9MAX の MP/LJ 等は分かりにくいため）。
  static const _table = TableType.sixMax;
  RangeSituation _situation = RangeSituation.openRaise;

  bool get _isOpen => _situation == RangeSituation.openRaise;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rangeRepositoryProvider);
    final callOrRaise = _isOpen ? RangeAction.raise : RangeAction.call;
    final heatmap = consolidate(repo, _table, _situation, callOrRaise);
    final threeBets = _isOpen ? <StartingHand>{} : threeBetHands(repo, _table);
    final legendPositions = positionsByWidth(
      repo,
      _table,
      _situation,
      callOrRaise,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('レンジ表（6MAX）')),
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
            ChoiceChipGroup<RangeSituation>(
              values: const [RangeSituation.openRaise, RangeSituation.vsOpen],
              selected: _situation,
              labelBuilder: (v) =>
                  v == RangeSituation.openRaise ? 'オープンする' : 'オープンに対応する',
              onSelected: (v) => setState(() => _situation = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Text(
                _isOpen
                    ? '各ハンドを「オープンする一番レンジが狭い席」の色で表示。'
                          '色が広がる（薄い色）ほど後ろの席まで含む＝レンジが広がります。'
                          'ある席のオープンレンジ＝その色＋それより濃い（狭い）色すべて。'
                    : 'オープンに対して、コールする席は席の色、3ベットは共通の黒、'
                          'フォールドは灰で表示しています。',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(aspectRatio: 1, child: _grid(heatmap, threeBets)),
            const SizedBox(height: AppSpacing.lg),
            _legend(legendPositions),
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

  Widget _grid(
    Map<StartingHand, Position> heatmap,
    Set<StartingHand> threeBets,
  ) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(
                    child: _cell(
                      StartingHand.fromGrid(row, col),
                      heatmap,
                      threeBets,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(
    StartingHand hand,
    Map<StartingHand, Position> heatmap,
    Set<StartingHand> threeBets,
  ) {
    final Color bg;
    final Color fg;
    if (threeBets.contains(hand)) {
      bg = _threeBetColor;
      fg = Colors.white;
    } else if (heatmap[hand] case final pos?) {
      bg = positionColor(pos).withValues(alpha: 0.85);
      fg = Colors.white;
    } else {
      bg = AppColors.rangeFold;
      fg = AppColors.textMuted;
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isOpen ? '色＝オープンする席（左＝狭い → 右＝広い）' : '色＝コールする席（左＝狭い → 右＝広い）',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in positions) _legendChip(positionColor(p), p.label),
              if (!_isOpen) _legendChip(_threeBetColor, '3ベット'),
              _legendChip(AppColors.rangeFold, 'フォールド'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color == AppColors.rangeFold
                ? color
                : color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showHandPositions(StartingHand hand) {
    final repo = ref.read(rangeRepositoryProvider);
    final summary = handPositionSummary(repo, _table, hand);
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
