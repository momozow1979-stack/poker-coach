import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../gto_strategy/application/gto_flop_providers.dart';
import '../application/consolidated_range.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_spot.dart';
import 'widgets/range_cell.dart';

/// 全席が3ベットする（共通の）3ベットを表す黒。
const Color _threeBetColor = Color(0xFF1F2937);

/// vsオープン表の表示切り替え。
enum _VsView { call, raise, merge }

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
  _VsView _vsView = _VsView.merge;

  bool get _isOpen => _situation == RangeSituation.openRaise;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rangeRepositoryProvider);
    final callOrRaise = _isOpen ? RangeAction.raise : RangeAction.call;
    final heatmap = _isOpen
        ? consolidate(repo, _table, _situation, callOrRaise)
        : const <StartingHand, Position>{};
    final vsMap = _isOpen
        ? const <StartingHand, VsOpenCell>{}
        : consolidateVsOpen(repo, _table);
    final legendAction = _isOpen
        ? RangeAction.raise
        : (_vsView == _VsView.raise ? RangeAction.threeBet : RangeAction.call);
    final legendPositions = positionsByWidth(
      repo,
      _table,
      _situation,
      legendAction,
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
            if (ref
                    .watch(gtoFlopStrategyProvider)
                    .asData
                    ?.value
                    .spots
                    .isNotEmpty ??
                false) ...[
              _gtoEntry(context),
              const SizedBox(height: AppSpacing.md),
            ],
            ChoiceChipGroup<RangeSituation>(
              values: const [RangeSituation.openRaise, RangeSituation.vsOpen],
              selected: _situation,
              labelBuilder: (v) =>
                  v == RangeSituation.openRaise ? 'オープン' : 'vsオープン',
              onSelected: (v) => setState(() => _situation = v),
            ),
            if (!_isOpen) ...[
              const SizedBox(height: AppSpacing.sm),
              ChoiceChipGroup<_VsView>(
                values: const [_VsView.call, _VsView.raise, _VsView.merge],
                selected: _vsView,
                labelBuilder: (v) => switch (v) {
                  _VsView.call => 'コールのみ',
                  _VsView.raise => 'レイズのみ',
                  _VsView.merge => 'マージ',
                },
                onSelected: (v) => setState(() => _vsView = v),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Text(
                _description(),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(aspectRatio: 1, child: _grid(heatmap, vsMap)),
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

  Widget _gtoEntry(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/range/gto'),
      child: AppCard(
        child: Row(
          children: [
            const Icon(Icons.insights, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'GTOフロップ戦略',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _description() {
    if (_isOpen) {
      return '各ハンドを「オープンする一番レンジが狭い席」の色で表示。'
          '色が広がる（薄い色）ほど後ろの席まで含む＝レンジが広がります。'
          'ある席のオープンレンジ＝その色＋それより濃い（狭い）色すべて。';
    }
    return switch (_vsView) {
      _VsView.call =>
        'コールする席を色で表示。全席が3ベットするハンド（プレミアム）は黒で出すので、'
            'フォールド（灰）と混ざりません。色は一番狭い席の目安で、正確な全席はタップで確認できます。',
      _VsView.raise =>
        '3ベットする席を色で表示。全席が3ベットするハンドは黒、それ以外は一番狭い3ベット席の色。'
            'フォールドは灰。正確な全席はタップで確認できます。',
      _VsView.merge =>
        'コール＝下の色 / 3ベット＝上の色で表示。席で判断が割れるハンドは'
            '左上＝3ベット席・右下＝コール席のツートン、全席が3ベットするハンドは黒。',
    };
  }

  Widget _grid(
    Map<StartingHand, Position> heatmap,
    Map<StartingHand, VsOpenCell> vsMap,
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
                      vsMap,
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
    Map<StartingHand, VsOpenCell> vsMap,
  ) {
    Color top;
    Color bottom;
    Color fg = Colors.white;

    if (_isOpen) {
      if (heatmap[hand] case final pos?) {
        top = bottom = positionColor(pos).withValues(alpha: 0.85);
      } else {
        top = bottom = AppColors.rangeFold;
        fg = AppColors.textMuted;
      }
    } else {
      final cell = vsMap[hand] ?? const VsOpenCell();
      (top, bottom, fg) = _vsColors(cell);
    }

    return RangeCell(
      code: hand.code,
      topColor: top,
      bottomColor: bottom,
      textColor: fg,
      onTap: () => _showHandPositions(hand),
    );
  }

  /// vsオープンのセル色を、選択中の表示（コールのみ / レイズのみ / マージ）で決める。
  (Color, Color, Color) _vsColors(VsOpenCell cell) {
    Color solid(Position p) => positionColor(p).withValues(alpha: 0.85);
    const fold = (
      AppColors.rangeFold,
      AppColors.rangeFold,
      AppColors.textMuted,
    );
    const black = (_threeBetColor, _threeBetColor, Colors.white);
    switch (_vsView) {
      case _VsView.call:
        // 全席3ベットのプレミアムは黒（フォールドと混ざらないように）。
        if (cell.commonThreeBet) return black;
        if (cell.callPos case final p?) {
          return (solid(p), solid(p), Colors.white);
        }
        return fold;
      case _VsView.raise:
        if (cell.commonThreeBet) return black;
        if (cell.threeBetPos case final p?) {
          return (solid(p), solid(p), Colors.white);
        }
        return fold;
      case _VsView.merge:
        if (cell.commonThreeBet) return black;
        if (cell.isSplit) {
          return (solid(cell.threeBetPos!), solid(cell.callPos!), Colors.white);
        }
        if (cell.callPos case final p?) {
          return (solid(p), solid(p), Colors.white);
        }
        if (cell.threeBetPos case final p?) {
          return (solid(p), solid(p), Colors.white);
        }
        return fold;
    }
  }

  Widget _legend(List<Position> positions) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isOpen
                ? '色＝オープンする席（左＝狭い → 右＝広い）'
                : _vsView == _VsView.raise
                ? '色＝3ベットする席（左＝狭い → 右＝広い）'
                : '色＝コールする席（左＝狭い → 右＝広い）',
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
              if (!_isOpen) _legendChip(_threeBetColor, '共通3ベット'),
              if (!_isOpen && _vsView == _VsView.merge) _splitLegendChip(),
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

  /// ツートン（判断が割れる）の凡例。左上＝3ベット席・右下＝コール席。
  Widget _splitLegendChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CustomPaint(painter: _LegendSplitPainter()),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Text(
          '割れ（上=3ベット / 下=コール）',
          style: TextStyle(
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

/// 凡例用の小さなツートン見本（左下がり／：左上＝3ベット席色・右下＝コール席色）。
class _LegendSplitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.clipRRect(rrect);
    final paint = Paint()..style = PaintingStyle.fill;
    // 上側（左上）＝3ベット席色: (0,0)-(w,0)-(0,h)
    paint.color = positionColor(Position.btn).withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(0, h)
        ..close(),
      paint,
    );
    // 下側（右下）＝コール席色: (w,0)-(w,h)-(0,h)
    paint.color = positionColor(Position.hj).withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_LegendSplitPainter oldDelegate) => false;
}
