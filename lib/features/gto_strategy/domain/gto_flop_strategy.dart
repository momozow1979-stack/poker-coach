import '../../../shared/models/playing_card.dart';

/// ソルバー（`solver/`）で学習した、フロップの c-bet 戦略。
///
/// `solver/solve_srp_btn_bb.py` の出力（`assets/gto/solved_srp_btn_bb.json`）を
/// 読み込んだもの。各数値は `CFRSolver.average_strategy()` の読み出しを 169 の
/// スターティングハンドクラスへ平均したベット頻度で、捏造・推測は無い。
class GtoFlopStrategy {
  const GtoFlopStrategy({required this.spots});

  final List<GtoFlopSpot> spots;

  static const empty = GtoFlopStrategy(spots: []);

  factory GtoFlopStrategy.fromJson(Map<String, dynamic> json) {
    final rawSpots = json['spots'];
    return GtoFlopStrategy(
      spots: rawSpots is List
          ? [
              for (final spot in rawSpots)
                GtoFlopSpot.fromJson(spot as Map<String, dynamic>),
            ]
          : const [],
    );
  }
}

/// 1つのフロップ（3枚）についての、ハンドクラス別 c-bet 頻度。
class GtoFlopSpot {
  const GtoFlopSpot({
    required this.id,
    required this.board,
    required this.betByCode,
  });

  final String id;
  final List<PlayingCard> board;

  /// ハンドクラス（`'AA'`, `'AKs'`, `'AKo'` …）→ ベット頻度（0.0〜1.0）。
  final Map<String, double> betByCode;

  /// [code] のベット頻度。データが無ければ null。
  double? betFor(String code) => betByCode[code];

  /// `solver/solve_srp_btn_bb.py` の出力は、フロップ最初の意思決定ノードを
  /// `flop.oop_first` に持つ（PR #87 でターン・リバー・レイズ対応に拡張された
  /// スキーマ。チェック(`'x'`)と4段階のベットサイズ(`'1'`〜`'4'`)の頻度が別々に
  /// 入っているため、この画面（c-bet するか/しないかの二値ヒートマップ）向けに
  /// 「ベットサイズ問わず何かしらベットする頻度」＝チェック以外の合計へ畳み込む。
  factory GtoFlopSpot.fromJson(Map<String, dynamic> json) {
    final flop = json['flop'] as Map<String, dynamic>? ?? const {};
    final classes = flop['oop_first'] as Map<String, dynamic>? ?? const {};
    return GtoFlopSpot(
      id: json['id'] as String,
      board: PlayingCard.parseAll((json['board'] as List).cast<String>()),
      betByCode: {
        for (final entry in classes.entries)
          entry.key: _totalBetFrequency(entry.value as Map<String, dynamic>),
      },
    );
  }

  static double _totalBetFrequency(Map<String, dynamic> row) {
    var total = 0.0;
    for (final entry in row.entries) {
      if (entry.key == 'combos' || entry.key == 'x') continue;
      total += (entry.value as num).toDouble();
    }
    return total;
  }
}
