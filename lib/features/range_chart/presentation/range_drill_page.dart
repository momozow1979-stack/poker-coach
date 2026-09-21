import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../application/consolidated_range.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_repository.dart';
import '../domain/range_spot.dart';
import 'widgets/range_cell.dart';

/// 全席が3ベットする（共通の）3ベットを表す黒。
const Color _blackColor = Color(0xFF1F2937);

/// vsオープンで塗るときのブラシ種別。
enum _VsBrush { call, threeBet, black, erase }

/// レンジ表暗記ドリル（1枚の集約表を塗り絵で再現する）。
///
/// 表と同じ 1 枚に、ポジション色を筆にして塗る。
/// * オープン: 席を選んで、その席が「一番狭くオープンし始める」マスを塗る。
/// * vsオープン: 「コール+席」「3ベット+席」を選んで塗る。同じマスに両方を塗ると
///   左下=コール席・右上=3ベット席のツートンになる（順番はどちらが先でもよい）。
///   全席が3ベットするプレミアムは「共通3ベット(黒)」で塗る。
/// 最後に「回答する」で、集約表の正解と一致するか採点する。
class RangeDrillPage extends ConsumerStatefulWidget {
  const RangeDrillPage({super.key});

  @override
  ConsumerState<RangeDrillPage> createState() => _RangeDrillPageState();
}

class _RangeDrillPageState extends ConsumerState<RangeDrillPage> {
  // 覚えやすさ優先で 6MAX のみ扱う。
  final TableType _table = TableType.sixMax;
  RangeSituation _situation = RangeSituation.openRaise;

  // オープン: 塗った席。
  final Map<StartingHand, Position> _openPaint = {};
  Position? _openBrush;

  // vsオープン: コール/3ベットで塗った席と、共通3ベット(黒)。
  final Map<StartingHand, Position> _callPaint = {};
  final Map<StartingHand, Position> _threeBetPaint = {};
  final Set<StartingHand> _blackPaint = {};
  _VsBrush _vsBrush = _VsBrush.call;
  Position? _vsPos;

  bool _graded = false;

  bool get _isOpen => _situation == RangeSituation.openRaise;

  void _reset() {
    _openPaint.clear();
    _callPaint.clear();
    _threeBetPaint.clear();
    _blackPaint.clear();
    _graded = false;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rangeRepositoryProvider);
    final openPositions = positionsByWidth(
      repo,
      _table,
      RangeSituation.openRaise,
      RangeAction.raise,
    );
    final callPositions = positionsByWidth(
      repo,
      _table,
      RangeSituation.vsOpen,
      RangeAction.call,
    );
    final threeBetPositions = positionsByWidth(
      repo,
      _table,
      RangeSituation.vsOpen,
      RangeAction.threeBet,
    );

    // ブラシの初期値。
    _openBrush ??= openPositions.isEmpty ? null : openPositions.first;

    return Scaffold(
      appBar: AppBar(title: const Text('レンジ表暗記')),
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
              child: _controls(openPositions, callPositions, threeBetPositions),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: AspectRatio(aspectRatio: 1, child: _grid(repo)),
                ),
              ),
            ),
            _bottomBar(repo),
          ],
        ),
      ),
    );
  }

  Widget _controls(
    List<Position> openPositions,
    List<Position> callPositions,
    List<Position> threeBetPositions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _situationToggle(),
        const SizedBox(height: AppSpacing.sm),
        if (_isOpen)
          _positionBrushes(
            openPositions,
            selected: _openBrush,
            onTap: (p) => setState(() => _openBrush = p),
          )
        else ...[
          _vsActionToggle(),
          const SizedBox(height: AppSpacing.xs),
          if (_vsBrush == _VsBrush.call)
            _positionBrushes(
              callPositions,
              selected: _vsPos,
              onTap: (p) => setState(() => _vsPos = p),
            )
          else if (_vsBrush == _VsBrush.threeBet)
            _positionBrushes(
              threeBetPositions,
              selected: _vsPos,
              onTap: (p) => setState(() => _vsPos = p),
            ),
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
    if (_isOpen) {
      return '席を選んで、その席が一番狭くオープンし始めるハンドを塗る';
    }
    return 'コール+席／3ベット+席で塗る。同じマスに両方でツートン。プレミアムは共通3ベット(黒)';
  }

  Widget _situationToggle() {
    return _chipRow<RangeSituation>(
      values: const [RangeSituation.openRaise, RangeSituation.vsOpen],
      labels: const {
        RangeSituation.openRaise: 'オープン',
        RangeSituation.vsOpen: 'vsオープン',
      },
      selected: _situation,
      onSelected: (v) => setState(() {
        _situation = v;
        _vsPos = null;
        _vsBrush = _VsBrush.call;
        _reset();
      }),
    );
  }

  Widget _vsActionToggle() {
    return _chipRow<_VsBrush>(
      values: const [
        _VsBrush.call,
        _VsBrush.threeBet,
        _VsBrush.black,
        _VsBrush.erase,
      ],
      labels: const {
        _VsBrush.call: 'コール',
        _VsBrush.threeBet: '3ベット',
        _VsBrush.black: '共通3ベット(黒)',
        _VsBrush.erase: '消す',
      },
      selected: _vsBrush,
      onSelected: (v) => setState(() {
        _vsBrush = v;
        if (v == _VsBrush.black || v == _VsBrush.erase) _vsPos = null;
      }),
    );
  }

  Widget _positionBrushes(
    List<Position> positions, {
    required Position? selected,
    required ValueChanged<Position> onTap,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final p in positions)
          _colorChip(
            p.label,
            color: positionColor(p),
            selected: p == selected,
            onTap: () => onTap(p),
          ),
      ],
    );
  }

  Widget _grid(RangeRepository repo) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(child: _cell(StartingHand.fromGrid(row, col), repo)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, RangeRepository repo) {
    Color top;
    Color bottom;
    Color fg = Colors.white;
    Color? border;

    if (!_graded) {
      (top, bottom, fg) = _paintedColors(hand);
    } else {
      // 採点: 正解の色を出し、間違いは赤枠。
      final bool match;
      if (_isOpen) {
        final target = consolidate(
          repo,
          _table,
          RangeSituation.openRaise,
          RangeAction.raise,
        );
        final t = target[hand];
        match = _openPaint[hand] == t;
        if (t != null) {
          top = bottom = positionColor(t).withValues(alpha: 0.85);
        } else {
          top = bottom = AppColors.rangeFold;
          fg = AppColors.textMuted;
        }
      } else {
        final cell = vsOpenCellFor(repo, _table, hand);
        (top, bottom, fg) = _targetColors(cell);
        match = _vsMatches(hand, cell);
      }
      if (!match) border = AppColors.danger;
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

  /// いま塗られている状態の色。
  (Color, Color, Color) _paintedColors(StartingHand hand) {
    if (_isOpen) {
      final p = _openPaint[hand];
      if (p != null) {
        final c = positionColor(p).withValues(alpha: 0.85);
        return (c, c, Colors.white);
      }
      return (AppColors.surface, AppColors.surface, AppColors.textMuted);
    }
    if (_blackPaint.contains(hand)) {
      return (_blackColor, _blackColor, Colors.white);
    }
    final call = _callPaint[hand];
    final three = _threeBetPaint[hand];
    if (call != null && three != null) {
      return (
        positionColor(three).withValues(alpha: 0.85),
        positionColor(call).withValues(alpha: 0.85),
        Colors.white,
      );
    }
    if (call != null) {
      final c = positionColor(call).withValues(alpha: 0.85);
      return (c, c, Colors.white);
    }
    if (three != null) {
      final c = positionColor(three).withValues(alpha: 0.85);
      return (c, c, Colors.white);
    }
    return (AppColors.surface, AppColors.surface, AppColors.textMuted);
  }

  /// 正解セルの色（採点表示用）。
  (Color, Color, Color) _targetColors(VsOpenCell cell) {
    if (cell.commonThreeBet) {
      return (_blackColor, _blackColor, Colors.white);
    }
    if (cell.isSplit) {
      return (
        positionColor(cell.threeBetPos!).withValues(alpha: 0.85),
        positionColor(cell.callPos!).withValues(alpha: 0.85),
        Colors.white,
      );
    }
    if (cell.callPos case final p?) {
      final c = positionColor(p).withValues(alpha: 0.85);
      return (c, c, Colors.white);
    }
    if (cell.threeBetPos case final p?) {
      final c = positionColor(p).withValues(alpha: 0.85);
      return (c, c, Colors.white);
    }
    return (AppColors.rangeFold, AppColors.rangeFold, AppColors.textMuted);
  }

  bool _vsMatches(StartingHand hand, VsOpenCell cell) {
    if (cell.commonThreeBet) {
      return _blackPaint.contains(hand) &&
          _callPaint[hand] == null &&
          _threeBetPaint[hand] == null;
    }
    return !_blackPaint.contains(hand) &&
        _callPaint[hand] == cell.callPos &&
        _threeBetPaint[hand] == cell.threeBetPos;
  }

  void _paint(StartingHand hand) {
    setState(() {
      if (_isOpen) {
        if (_openBrush == null) return;
        if (_openPaint[hand] == _openBrush) {
          _openPaint.remove(hand);
        } else {
          _openPaint[hand] = _openBrush!;
        }
        return;
      }
      switch (_vsBrush) {
        case _VsBrush.call:
          if (_vsPos == null) return;
          _blackPaint.remove(hand);
          if (_callPaint[hand] == _vsPos) {
            _callPaint.remove(hand);
          } else {
            _callPaint[hand] = _vsPos!;
          }
        case _VsBrush.threeBet:
          if (_vsPos == null) return;
          _blackPaint.remove(hand);
          if (_threeBetPaint[hand] == _vsPos) {
            _threeBetPaint.remove(hand);
          } else {
            _threeBetPaint[hand] = _vsPos!;
          }
        case _VsBrush.black:
          if (_blackPaint.contains(hand)) {
            _blackPaint.remove(hand);
          } else {
            _blackPaint.add(hand);
            _callPaint.remove(hand);
            _threeBetPaint.remove(hand);
          }
        case _VsBrush.erase:
          _callPaint.remove(hand);
          _threeBetPaint.remove(hand);
          _blackPaint.remove(hand);
      }
    });
  }

  Widget _bottomBar(RangeRepository repo) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _graded
            ? _result(repo)
            : SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _hasPaint
                      ? () => setState(() => _graded = true)
                      : null,
                  child: const Text('回答する'),
                ),
              ),
      ),
    );
  }

  bool get _hasPaint => _isOpen
      ? _openPaint.isNotEmpty
      : _callPaint.isNotEmpty ||
            _threeBetPaint.isNotEmpty ||
            _blackPaint.isNotEmpty;

  Widget _result(RangeRepository repo) {
    var total = 0;
    var correct = 0;
    if (_isOpen) {
      final target = consolidate(
        repo,
        _table,
        RangeSituation.openRaise,
        RangeAction.raise,
      );
      for (final h in StartingHand.all) {
        final t = target[h];
        if (t == null) continue;
        total++;
        if (_openPaint[h] == t) correct++;
      }
    } else {
      for (final h in StartingHand.all) {
        final cell = vsOpenCellFor(repo, _table, h);
        if (cell.isFold) continue;
        total++;
        if (_vsMatches(h, cell)) correct++;
      }
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

  // ---- 小さなチップ部品 ----

  Widget _chipRow<T>({
    required List<T> values,
    required Map<T, String> labels,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
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
