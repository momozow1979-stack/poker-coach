import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';
import '../domain/range_spot.dart';

/// レンジ表暗記ドリル（塗って採点）。
///
/// 「シチュエーション（オープン / vsオープン）× ポジション × アクション」を選び、
/// 13×13 のマスをポチポチ塗って、最後に「回答する」で正誤を採点する。
/// Mixed は廃止し、境界のハンドは主アクション（blend.primary）に畳んで単一正解にする。
class RangeDrillPage extends ConsumerStatefulWidget {
  const RangeDrillPage({super.key});

  @override
  ConsumerState<RangeDrillPage> createState() => _RangeDrillPageState();
}

class _RangeDrillPageState extends ConsumerState<RangeDrillPage> {
  // 覚えやすさ優先で 6MAX のみ扱う。
  final TableType _table = TableType.sixMax;
  RangeSituation _situation = RangeSituation.openRaise;
  Position? _position;
  RangeAction _vsAction = RangeAction.call; // vsオープンのとき call / threeBet
  final Set<StartingHand> _selected = {};
  bool _graded = false;

  /// Mixed を廃止し、主アクションに畳む。
  RangeAction _effective(RangeEntry e) => e.action == RangeAction.mixed
      ? (e.blend?.primary ?? RangeAction.fold)
      : e.action;

  RangeAction get _target =>
      _situation == RangeSituation.openRaise ? RangeAction.raise : _vsAction;

  List<Position> _availablePositions() {
    final repo = ref.read(rangeRepositoryProvider);
    return [
      for (final p in Position.orderFor(_table))
        if (repo.chartFor(_table, p, situation: _situation) != null) p,
    ];
  }

  void _reset() {
    _selected.clear();
    _graded = false;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rangeRepositoryProvider);
    final positions = _availablePositions();
    if (_position == null || !positions.contains(_position)) {
      _position = positions.isEmpty ? null : positions.first;
    }
    final chart = _position == null
        ? null
        : repo.chartFor(_table, _position!, situation: _situation);

    return Scaffold(
      appBar: AppBar(title: const Text('レンジ表暗記')),
      body: SafeArea(
        child: chart == null
            ? const Center(child: Text('出題できるレンジ表がありません。'))
            : _buildBody(chart, positions),
      ),
    );
  }

  Widget _buildBody(RangeChart chart, List<Position> positions) {
    final correct = <StartingHand>{
      for (final h in StartingHand.all)
        if (_effective(chart.entryFor(h)) == _target) h,
    };
    final actionLabel = _target == RangeAction.raise
        ? 'レイズ'
        : _target == RangeAction.threeBet
        ? '3ベット'
        : 'コール';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _toggleRow<RangeSituation>(
                values: const [RangeSituation.openRaise, RangeSituation.vsOpen],
                selected: _situation,
                labels: const {
                  RangeSituation.openRaise: 'オープン',
                  RangeSituation.vsOpen: 'vsオープン',
                },
                onSelected: (v) => setState(() {
                  _situation = v;
                  _vsAction = RangeAction.call;
                  _position = null;
                  _reset();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final p in positions)
                    _chip(
                      p.label,
                      selected: p == _position,
                      onTap: () => setState(() {
                        _position = p;
                        _reset();
                      }),
                    ),
                ],
              ),
              if (_situation == RangeSituation.vsOpen) ...[
                const SizedBox(height: AppSpacing.sm),
                _toggleRow<RangeAction>(
                  values: const [RangeAction.call, RangeAction.threeBet],
                  selected: _vsAction,
                  labels: const {
                    RangeAction.call: 'コール',
                    RangeAction.threeBet: '3ベット',
                  },
                  onSelected: (v) => setState(() {
                    _vsAction = v;
                    _reset();
                  }),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                _graded
                    ? '正解: 緑 / 塗りすぎ: 赤 / 塗り漏れ: オレンジ'
                    : '「${_position?.label} の $actionLabelレンジ」だと思うマスを塗って、回答するを押す',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _grid(chart, correct)),
            ),
          ),
        ),
        _bottomBar(correct),
      ],
    );
  }

  Widget _grid(RangeChart chart, Set<StartingHand> correct) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(
                    child: _cell(StartingHand.fromGrid(row, col), correct),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, Set<StartingHand> correct) {
    final isSelected = _selected.contains(hand);
    Color bg;
    Color fg = AppColors.textPrimary;
    if (_graded) {
      final shouldBe = correct.contains(hand);
      if (isSelected && shouldBe) {
        bg = AppColors.rangeCall; // 正解
        fg = Colors.white;
      } else if (isSelected && !shouldBe) {
        bg = AppColors.danger; // 塗りすぎ
        fg = Colors.white;
      } else if (!isSelected && shouldBe) {
        bg = AppColors.reward; // 塗り漏れ
        fg = Colors.white;
      } else {
        bg = AppColors.surface;
        fg = AppColors.textMuted;
      }
    } else {
      bg = isSelected
          ? _target.color.withValues(alpha: 0.85)
          : AppColors.surface;
      if (isSelected) fg = Colors.white;
    }

    return GestureDetector(
      onTap: _graded
          ? null
          : () => setState(() {
              if (!_selected.add(hand)) _selected.remove(hand);
            }),
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

  Widget _bottomBar(Set<StartingHand> correct) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _graded
            ? _result(correct)
            : SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _graded = true),
                  child: const Text('回答する'),
                ),
              ),
      ),
    );
  }

  Widget _result(Set<StartingHand> correct) {
    final hit = _selected.where(correct.contains).length;
    final extra = _selected.length - hit;
    final missed = correct.length - hit;
    return Column(
      children: [
        Text(
          '正解 $hit / ${correct.length}・塗りすぎ $extra・塗り漏れ $missed',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(_reset),
            child: const Text('もう一度'),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow<T>({
    required List<T> values,
    required T selected,
    required Map<T, String> labels,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final v in values)
          _chip(
            labels[v] ?? '$v',
            selected: v == selected,
            onTap: () => onSelected(v),
          ),
      ],
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onAccent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
