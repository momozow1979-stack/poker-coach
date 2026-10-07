import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../../profile/application/progress_providers.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';
import '../domain/range_spot.dart';
import '../infrastructure/range_definitions.dart';
import 'widgets/range_cell.dart';

/// vsオープンで塗るときのブラシ種別。
enum _VsBrush { call, threeBet, erase }

/// ポジション別レンジ暗記ドリル。
///
/// 既存の [RangeDrillPage]（全ポジション集約の1枚塗り絵）とは別に、
/// ポジションを1つ選んで、そのポジション「だけ」のオープンレンジ・vsオープンレンジに
/// 集中して覚えるためのドリル。6MAXのみ対応（覚えやすさ優先、既存ページと同じ方針）。
///
/// ポジションごとに実在するシチュエーションは [RangeDefinitions.situationsFor] で
/// 判定する。BBは「オープン」が無く「vsオープン（vs BTN）」のみ、UTGは逆に
/// 「vsオープン」が無く「オープン」のみ、という非対称を、存在するチップだけ出す
/// ことでそのまま表現する（無い方を捏造して埋めない）。
class PositionRangeDrillPage extends ConsumerStatefulWidget {
  const PositionRangeDrillPage({super.key});

  @override
  ConsumerState<PositionRangeDrillPage> createState() =>
      _PositionRangeDrillPageState();
}

class _PositionRangeDrillPageState
    extends ConsumerState<PositionRangeDrillPage> {
  static const _table = TableType.sixMax;
  static const _positions = Position.sixMaxOrder;

  Position _position = Position.btn;
  RangeSituation _situation = RangeSituation.openRaise;

  final Set<StartingHand> _openPaint = {};
  final Map<StartingHand, RangeAction> _vsPaint = {};
  _VsBrush _vsBrush = _VsBrush.call;

  bool _graded = false;

  bool get _isOpen => _situation == RangeSituation.openRaise;

  void _reset() {
    _openPaint.clear();
    _vsPaint.clear();
    _graded = false;
  }

  List<RangeSituation> _availableSituations() =>
      RangeDefinitions.situationsFor(_table, _position);

  void _selectPosition(Position position) {
    setState(() {
      _position = position;
      final available = _availableSituations();
      if (!available.contains(_situation) && available.isNotEmpty) {
        _situation = available.first;
      }
      _reset();
    });
  }

  void _selectSituation(RangeSituation situation) {
    setState(() {
      _situation = situation;
      _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rangeRepositoryProvider);
    final chart = repo.chartFor(_table, _position, situation: _situation);
    final available = _availableSituations();
    final clears = ref.watch(drillProgressStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ポジション別レンジ暗記')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _controls(available, clears),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (chart != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _spotHeader(chart.spot),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Center(
                    child: AspectRatio(aspectRatio: 1, child: _grid(chart)),
                  ),
                ),
              ),
              _bottomBar(chart),
            ] else
              Expanded(child: _missingData()),
          ],
        ),
      ),
    );
  }

  Widget _missingData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '${_position.label}の${_situation.label}は、まだ実データを用意できていません。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _controls(List<RangeSituation> available, Set<String> clears) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _positionChips(clears),
        const SizedBox(height: AppSpacing.sm),
        _situationToggle(available),
        if (!_isOpen) ...[
          const SizedBox(height: AppSpacing.xs),
          _vsBrushToggle(),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          _graded ? '正解＝表示どおり／赤枠＝間違い' : _hint(),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _hint() {
    if (_isOpen) return 'このポジションがオープンするハンドを塗る';
    return 'コール／3ベットで塗る。塗らなければフォールド扱い';
  }

  Widget _positionChips(Set<String> clears) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final p in _positions)
          _chip(
            p.label,
            selected: p == _position,
            onTap: () => _selectPosition(p),
            cleared: RangeDefinitions.situationsFor(
              _table,
              p,
            ).every((s) => clears.contains(_drillKey(s, p))),
          ),
      ],
    );
  }

  Widget _situationToggle(List<RangeSituation> available) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in const [RangeSituation.openRaise, RangeSituation.vsOpen])
          if (available.contains(s))
            _chip(
              s == RangeSituation.openRaise ? 'オープン' : 'vsオープン',
              selected: s == _situation,
              onTap: () => _selectSituation(s),
            ),
      ],
    );
  }

  Widget _vsBrushToggle() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _colorChip(
          'コール',
          color: RangeAction.call.color,
          selected: _vsBrush == _VsBrush.call,
          onTap: () => setState(() => _vsBrush = _VsBrush.call),
        ),
        _colorChip(
          '3ベット',
          color: RangeAction.threeBet.color,
          selected: _vsBrush == _VsBrush.threeBet,
          onTap: () => setState(() => _vsBrush = _VsBrush.threeBet),
        ),
        _chip(
          '消す',
          selected: _vsBrush == _VsBrush.erase,
          onTap: () => setState(() => _vsBrush = _VsBrush.erase),
        ),
      ],
    );
  }

  Widget _spotHeader(RangeSpot spot) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spot.headline,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(RangeChart chart) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(
                    child: _cell(StartingHand.fromGrid(row, col), chart),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, RangeChart chart) {
    Color top;
    Color bottom;
    Color fg = Colors.white;
    Color? border;

    if (!_graded) {
      (top, bottom, fg) = _paintedColors(hand);
    } else {
      final entry = chart.entryFor(hand);
      (top, bottom, fg) = _targetColors(entry);
      if (!_isCorrect(hand, entry)) border = AppColors.danger;
    }

    return RangeCell(
      code: hand.code,
      topColor: top,
      bottomColor: bottom,
      textColor: fg,
      borderColor: border,
      borderWidth: border != null ? 2 : 0.5,
      onTap: _graded ? null : () => _paint(hand),
    );
  }

  (Color, Color, Color) _paintedColors(StartingHand hand) {
    if (_isOpen) {
      if (_openPaint.contains(hand)) {
        final c = RangeAction.raise.color;
        return (c, c, Colors.white);
      }
      return (AppColors.surface, AppColors.surface, AppColors.textMuted);
    }
    final action = _vsPaint[hand];
    if (action != null) {
      final c = action.color;
      return (c, c, Colors.white);
    }
    return (AppColors.surface, AppColors.surface, AppColors.textMuted);
  }

  (Color, Color, Color) _targetColors(RangeEntry entry) {
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend!;
      return (blend.primary.color, blend.secondary.color, Colors.white);
    }
    if (entry.action == RangeAction.fold) {
      return (AppColors.rangeFold, AppColors.rangeFold, AppColors.textMuted);
    }
    final c = entry.action.color;
    return (c, c, Colors.white);
  }

  bool _isCorrect(StartingHand hand, RangeEntry entry) {
    if (_isOpen) {
      final painted = _openPaint.contains(hand);
      if (entry.action == RangeAction.mixed) {
        final blend = entry.blend!;
        final sides = {blend.primary, blend.secondary};
        if (painted) return sides.contains(RangeAction.raise);
        return sides.contains(RangeAction.fold);
      }
      return painted == (entry.action == RangeAction.raise);
    }
    final painted = _vsPaint[hand] ?? RangeAction.fold;
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend!;
      return painted == blend.primary || painted == blend.secondary;
    }
    return painted == entry.action;
  }

  void _paint(StartingHand hand) {
    setState(() {
      if (_isOpen) {
        if (!_openPaint.remove(hand)) _openPaint.add(hand);
        return;
      }
      switch (_vsBrush) {
        case _VsBrush.call:
          if (_vsPaint[hand] == RangeAction.call) {
            _vsPaint.remove(hand);
          } else {
            _vsPaint[hand] = RangeAction.call;
          }
        case _VsBrush.threeBet:
          if (_vsPaint[hand] == RangeAction.threeBet) {
            _vsPaint.remove(hand);
          } else {
            _vsPaint[hand] = RangeAction.threeBet;
          }
        case _VsBrush.erase:
          _vsPaint.remove(hand);
      }
    });
  }

  Widget _bottomBar(RangeChart chart) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _graded
            ? _result(chart)
            : SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _hasPaint ? () => _grade(chart) : null,
                  child: const Text('回答する'),
                ),
              ),
      ),
    );
  }

  bool get _hasPaint => _isOpen ? _openPaint.isNotEmpty : _vsPaint.isNotEmpty;

  void _grade(RangeChart chart) {
    final perfect = _isPerfect(chart);
    setState(() => _graded = true);
    if (perfect) {
      ref
          .read(drillProgressStoreProvider.notifier)
          .markCleared(_drillKey(_situation, _position));
    }
  }

  bool _isPerfect(RangeChart chart) {
    for (final h in StartingHand.all) {
      if (!_isCorrect(h, chart.entryFor(h))) return false;
    }
    return true;
  }

  String _drillKey(RangeSituation situation, Position position) =>
      'pos_${_table.id}_${situation.id}_${position.label}';

  Widget _result(RangeChart chart) {
    var total = 0;
    var correct = 0;
    for (final h in StartingHand.all) {
      final entry = chart.entryFor(h);
      if (entry.action == RangeAction.fold) continue;
      total++;
      if (_isCorrect(h, entry)) correct++;
    }
    return Column(
      children: [
        Text(
          '正解 $correct / $total',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    bool cleared = false,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onAccent : AppColors.textSecondary,
              ),
            ),
            if (cleared) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: 13,
                color: selected ? AppColors.onAccent : AppColors.success,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _colorChip(
    String label, {
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.85) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
