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

/// vsオープンの集約表・ドリルで、1ハンドを 1 マスにどう塗るかの判定結果。
///
/// コール／3ベットは席ごとに相手が違う＝レンジが入れ子ではないため、色は
/// 「そのアクションを取る一番レンジが狭い（早い）席」を代表色にする。正確な
/// 全席はタップ詳細（[handPositionSummary]）で確認する前提。
/// * どの席もコールせず全席が3ベット → [commonThreeBet]（共通の黒）
/// * コールと3ベットが割れる → [callPos]（下）＋[threeBetPos]（上）のツートン
class VsOpenCell {
  const VsOpenCell({
    this.callPos,
    this.threeBetPos,
    this.commonThreeBet = false,
  });

  /// 一番狭くコールする席（無ければ null）。
  final Position? callPos;

  /// 一番狭く3ベットする席（無ければ null）。
  final Position? threeBetPos;

  /// 全席が3ベット（＝共通の黒で塗る）。
  final bool commonThreeBet;

  bool get isFold =>
      callPos == null && threeBetPos == null && !commonThreeBet;

  /// コールする席と3ベットする席が両方ある（ツートン）。
  bool get isSplit => callPos != null && threeBetPos != null;
}

/// 1ハンドの vsオープン集約セルを判定する。
VsOpenCell vsOpenCellFor(
  RangeRepository repo,
  TableType tableType,
  StartingHand hand,
) {
  final positions = positionsWithChart(repo, tableType, RangeSituation.vsOpen);
  final callers = <Position>[];
  final threeBetters = <Position>[];
  for (final p in positions) {
    final chart = repo.chartFor(tableType, p, situation: RangeSituation.vsOpen)!;
    switch (_effective(chart.entryFor(hand))) {
      case RangeAction.call:
        callers.add(p);
      case RangeAction.threeBet:
        threeBetters.add(p);
      default:
        break;
    }
  }
  if (callers.isEmpty && threeBetters.isEmpty) return const VsOpenCell();

  // 全席が3ベット（誰もコールしない）＝共通の黒。
  final common =
      callers.isEmpty && threeBetters.length == positions.length;

  final byCallWidth =
      positionsByWidth(repo, tableType, RangeSituation.vsOpen, RangeAction.call);
  final byThreeWidth = positionsByWidth(
    repo,
    tableType,
    RangeSituation.vsOpen,
    RangeAction.threeBet,
  );
  Position? narrowest(List<Position> among, List<Position> order) {
    for (final p in order) {
      if (among.contains(p)) return p;
    }
    return among.isEmpty ? null : among.first;
  }

  return VsOpenCell(
    callPos: callers.isEmpty ? null : narrowest(callers, byCallWidth),
    threeBetPos: threeBetters.isEmpty
        ? null
        : narrowest(threeBetters, byThreeWidth),
    commonThreeBet: common,
  );
}

/// vsオープンの全169ハンドのセル判定。
Map<StartingHand, VsOpenCell> consolidateVsOpen(
  RangeRepository repo,
  TableType tableType,
) => {
  for (final hand in StartingHand.all)
    hand: vsOpenCellFor(repo, tableType, hand),
};

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
