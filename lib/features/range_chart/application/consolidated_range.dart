import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';
import '../domain/range_repository.dart';
import '../domain/range_spot.dart';

// ポジション色はアプリ共通の定義を使う（重複させない）。
export '../../../shared/theme/position_palette.dart' show positionColor;

/// ポジション別に色分けした「集約レンジ表」を作るためのヘルパー。
///
/// オープンはポジションが後ろになるほど広がる（前のポジションのレンジを含む）。
/// そこで「そのハンドで最初にそのアクションを取る一番タイトなポジション」で
/// 色を決めると、1枚の表でレンジの広がりが見える。Mixed は廃止し主アクションに畳む。

RangeAction _effective(RangeEntry entry) => entry.action == RangeAction.mixed
    ? (entry.blend?.primary ?? RangeAction.fold)
    : entry.action;

/// [action] を取るハンド数（レンジの広さ）。並び順の判定に使う。
int _rangeWidth(
  RangeRepository repo,
  TableType tableType,
  Position position,
  RangeSituation situation,
  RangeAction action,
) {
  final chart = repo.chartFor(tableType, position, situation: situation);
  if (chart == null) return 0;
  return StartingHand.all
      .where((h) => _effective(chart.entryFor(h)) == action)
      .length;
}

/// そのシチュエーション・アクションで表があるポジションを「レンジが狭い順→広い順」に並べる。
/// （オープンやコールは席の行動順とレンジの広さが必ずしも一致しない＝SB等があるため、
///  実際の枚数で並べる。）
List<Position> positionsByWidth(
  RangeRepository repo,
  TableType tableType,
  RangeSituation situation,
  RangeAction action,
) {
  final list = positionsWithChart(repo, tableType, situation);
  list.sort(
    (a, b) => _rangeWidth(
      repo,
      tableType,
      a,
      situation,
      action,
    ).compareTo(_rangeWidth(repo, tableType, b, situation, action)),
  );
  return list;
}

/// 各ハンドを「そのアクションを取る一番レンジが狭いポジション」に対応づける。
/// 狭い順に塗るので、あるポジションの全レンジ＝「その色＋それより狭い色」になる。
/// どのポジションも取らないハンドは含めない（＝フォールド扱い）。
Map<StartingHand, Position> consolidate(
  RangeRepository repo,
  TableType tableType,
  RangeSituation situation,
  RangeAction action,
) {
  final result = <StartingHand, Position>{};
  for (final position in positionsByWidth(repo, tableType, situation, action)) {
    final chart = repo.chartFor(tableType, position, situation: situation)!;
    for (final hand in StartingHand.all) {
      if (result.containsKey(hand)) continue; // より狭いポジションで確定済み
      if (_effective(chart.entryFor(hand)) == action) result[hand] = position;
    }
  }
  return result;
}

/// vsオープンで、どこかのポジションが3ベットするハンド（表示・出題で共通の黒にする）。
Set<StartingHand> threeBetHands(RangeRepository repo, TableType tableType) {
  final result = <StartingHand>{};
  for (final position in Position.orderFor(tableType)) {
    final chart = repo.chartFor(
      tableType,
      position,
      situation: RangeSituation.vsOpen,
    );
    if (chart == null) continue;
    for (final hand in StartingHand.all) {
      if (_effective(chart.entryFor(hand)) == RangeAction.threeBet) {
        result.add(hand);
      }
    }
  }
  return result;
}

/// このシチュエーションで表が存在するポジション一覧（席の行動順）。
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
