import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';
import '../domain/range_repository.dart';
import '../domain/range_spot.dart';

/// ポジション別に色分けした「集約レンジ表」を作るためのヘルパー。
///
/// オープンはポジションが後ろになるほど広がる（前のポジションのレンジを含む）。
/// そこで「そのハンドで最初にそのアクションを取る一番タイトなポジション」で
/// 色を決めると、1枚の表でレンジの広がりが見える。Mixed は廃止し主アクションに畳む。

const List<Color> _positionPalette = [
  AppColors.rangeFourBet,
  AppColors.rangeThreeBet,
  AppColors.rangeRaise,
  AppColors.reward,
  AppColors.accent,
  AppColors.info,
  AppColors.rangeCall,
  AppColors.danger,
];

/// ポジションごとの表示色（表・凡例で共通に使う）。
Color positionColor(Position position) =>
    _positionPalette[Position.values.indexOf(position) %
        _positionPalette.length];

RangeAction _effective(RangeEntry entry) => entry.action == RangeAction.mixed
    ? (entry.blend?.primary ?? RangeAction.fold)
    : entry.action;

/// 各ハンドを「そのアクションを取る一番タイトな（早い）ポジション」に対応づける。
/// どのポジションも取らないハンドは含めない（＝フォールド扱い）。
Map<StartingHand, Position> consolidate(
  RangeRepository repo,
  TableType tableType,
  RangeSituation situation,
  RangeAction action,
) {
  final result = <StartingHand, Position>{};
  for (final position in Position.orderFor(tableType)) {
    final chart = repo.chartFor(tableType, position, situation: situation);
    if (chart == null) continue;
    for (final hand in StartingHand.all) {
      if (result.containsKey(hand)) continue; // より早いポジションで確定済み
      if (_effective(chart.entryFor(hand)) == action) result[hand] = position;
    }
  }
  return result;
}

/// このシチュエーション・アクションで、実際に表が存在するポジション一覧（早い順）。
List<Position> positionsWithChart(
  RangeRepository repo,
  TableType tableType,
  RangeSituation situation,
) => [
  for (final position in Position.orderFor(tableType))
    if (repo.chartFor(tableType, position, situation: situation) != null)
      position,
];

/// 1つのハンドについて、各アクションを取るポジションの一覧（タップ詳細用）。
class HandPositionSummary {
  const HandPositionSummary({
    required this.opens,
    required this.calls,
    required this.threeBets,
  });

  /// オープンする（レイズ）ポジション。
  final List<Position> opens;

  /// vsオープンでコールするポジション。
  final List<Position> calls;

  /// vsオープンで3ベットするポジション。
  final List<Position> threeBets;
}

HandPositionSummary handPositionSummary(
  RangeRepository repo,
  TableType tableType,
  StartingHand hand,
) {
  List<Position> take(RangeSituation situation, RangeAction action) => [
    for (final position in Position.orderFor(tableType))
      if (repo.chartFor(tableType, position, situation: situation)
          case final c?)
        if (_effective(c.entryFor(hand)) == action) position,
  ];

  return HandPositionSummary(
    opens: take(RangeSituation.openRaise, RangeAction.raise),
    calls: take(RangeSituation.vsOpen, RangeAction.call),
    threeBets: take(RangeSituation.vsOpen, RangeAction.threeBet),
  );
}
