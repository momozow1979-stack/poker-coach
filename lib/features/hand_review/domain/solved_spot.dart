import '../../../shared/models/playing_card.dart';

/// CFR ソルバー（`solver/`、このリポジトリ内の Python 実装）で実際に学習・
/// exploitability 検証済みの1局面。
///
/// `solver/export_solved_spots.py` の出力（`assets/solved_spots/solved_spots.json`）
/// をそのまま読み込んだもの。ここに入っている数値はすべて
/// `CFRSolver.average_strategy()` の直接の読み出しで、捏造・推測は無い
/// （`solver/BENCHMARKS.md` に実測の exploitability を記録済み）。
///
/// 現状はヒーローの「フロップ最初の判断」1点だけを持つ（ターン・リバーや
/// 相手視点の判断は未収録）。対応ボード・レンジを広げるのは今後の課題。
class SolvedSpot {
  const SolvedSpot({
    required this.id,
    required this.boardFlop,
    required this.heroRangeNotation,
    required this.villainRangeNotation,
    required this.iterationsTrained,
    required this.measuredExactExploitability,
    required this.entries,
  });

  final String id;
  final List<PlayingCard> boardFlop;

  /// この局面でヒーロー役が持つレンジの表記（例: `'AA'`、`'QQ+'`）。
  final String heroRangeNotation;

  /// この局面で相手が持つ、という前提のレンジ表記（例: `'KK'`）。
  /// 実際の相手が本当にこのレンジ通りとは限らない前提であることを、
  /// 表示側で必ず明示する。
  final String villainRangeNotation;

  final int iterationsTrained;

  /// 学習後に実測した厳密 exploitability（0 に近いほど正確な均衡に近い）。
  final double measuredExactExploitability;

  final List<SolvedSpotEntry> entries;

  factory SolvedSpot.fromJson(Map<String, dynamic> json) => SolvedSpot(
    id: json['id'] as String,
    boardFlop: PlayingCard.parseAll(
      (json['board_flop'] as List).cast<String>(),
    ),
    heroRangeNotation: json['hero_range_notation'] as String,
    villainRangeNotation: json['villain_range_notation'] as String,
    iterationsTrained: json['iterations_trained'] as int,
    measuredExactExploitability: (json['measured_exact_exploitability'] as num)
        .toDouble(),
    entries: [
      for (final entry in json['entries'] as List)
        SolvedSpotEntry.fromJson(entry as Map<String, dynamic>),
    ],
  );
}

/// 1つの具体的なハンド（コンボ）についての、実測済みの行動頻度。
class SolvedSpotEntry {
  const SolvedSpotEntry({required this.heroCombo, required this.strategy});

  final List<PlayingCard> heroCombo;

  /// アクショントークン（`x`=チェック, `b`=ベット, `c`=コール, `f`=フォールド）
  /// ごとの頻度。合計は1になる。
  final Map<String, double> strategy;

  factory SolvedSpotEntry.fromJson(Map<String, dynamic> json) =>
      SolvedSpotEntry(
        heroCombo: PlayingCard.parseAll(
          (json['hero_combo'] as List).cast<String>(),
        ),
        strategy: (json['strategy'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      );
}
