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

  factory GtoFlopSpot.fromJson(Map<String, dynamic> json) {
    final classes = json['classes'] as Map<String, dynamic>? ?? const {};
    return GtoFlopSpot(
      id: json['id'] as String,
      board: PlayingCard.parseAll((json['board'] as List).cast<String>()),
      betByCode: {
        for (final entry in classes.entries)
          entry.key: ((entry.value as Map<String, dynamic>)['bet'] as num)
              .toDouble(),
      },
    );
  }
}
