import '../../../shared/models/playing_card.dart';

/// [SolvedSpotRepository.firstFlopDecisionMatches] の1件の結果。
///
/// 相手のレンジは「学習時に仮定したレンジ」であって、実際の相手が
/// そうだと確定しているわけではない — これを常に一緒に見せることで、
/// 「唯一のGTOの答え」であるかのような誤解を防ぐ。
class FlopDecisionMatch {
  const FlopDecisionMatch({
    required this.spotId,
    required this.villainRangeNotation,
    required this.strategy,
    required this.iterationsTrained,
    required this.measuredExactExploitability,
  });

  final String spotId;
  final String villainRangeNotation;
  final Map<String, double> strategy;
  final int iterationsTrained;
  final double measuredExactExploitability;
}

/// 実際に CFR ソルバーで解いた局面を検索するリポジトリ。
///
/// `assets/solved_spots/solved_spots.json`（`solver/export_solved_spots.py`
/// の出力）を読み込む実装を [AssetSolvedSpotRepository] に持つ。
abstract interface class SolvedSpotRepository {
  /// 初回アクセス前に読み込みを済ませる。何度呼んでも安全。
  Future<void> ensureLoaded();

  /// ヒーローの「フロップ最初の判断」に一致する、解けたスポットをすべて返す。
  ///
  /// [flopBoard] は順不同の3枚、[heroHand] は順不同の2枚で比較する。
  /// 一致が無ければ空リスト。同じボード・同じハンドでも相手レンジの
  /// 仮定が異なる複数のスポットがあり得るため、リストで返す
  /// （呼び出し側は全件を、相手レンジの仮定を明示した上で提示する）。
  List<FlopDecisionMatch> firstFlopDecisionMatches({
    required List<PlayingCard> heroHand,
    required List<PlayingCard> flopBoard,
  });
}
