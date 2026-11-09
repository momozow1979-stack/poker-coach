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
    this.turns = const {},
    this.rivers = const {},
  });

  final String id;
  final List<PlayingCard> board;

  /// ハンドクラス（`'AA'`, `'AKs'`, `'AKo'` …）→ ベット頻度（0.0〜1.0）。
  final Map<String, double> betByCode;

  /// ターンの代表カード読み出し。キーは `'blank'`（無関係な低いカード）・
  /// `'over'`（オーバーカード）・`'texture'`（フラッシュ完成 or ボードペア）。
  /// `solve_srp_btn_bb.py` は全てのターンカードではなくこの3枚だけを読み出し、
  /// かつ**フロップがチェックで進んだ場合のみ**を対象にしている
  /// （スキーマのdocstring参照）。
  final Map<String, GtoStreetNode> turns;

  /// リバーの代表カード読み出し。キーは「ターンのバケット→リバーのバケット
  /// （`'blank'`/`'scare'`）」の二重構造——読み出したリバーはそのターンの
  /// 代表カードを前提にしているため。turns 同様、フロップ・ターンの両方が
  /// チェックで進んだ場合のみを対象にしている。
  final Map<String, Map<String, GtoStreetNode>> rivers;

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
    final rawTurns = json['turns'] as Map<String, dynamic>? ?? const {};
    final rawRivers = json['rivers'] as Map<String, dynamic>? ?? const {};
    return GtoFlopSpot(
      id: json['id'] as String,
      board: PlayingCard.parseAll((json['board'] as List).cast<String>()),
      betByCode: {
        for (final entry in classes.entries)
          entry.key: _totalBetFrequency(entry.value as Map<String, dynamic>),
      },
      turns: {
        for (final entry in rawTurns.entries)
          entry.key: GtoStreetNode.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      rivers: {
        for (final entry in rawRivers.entries)
          entry.key: {
            for (final riverEntry
                in (entry.value as Map<String, dynamic>).entries)
              riverEntry.key: GtoStreetNode.fromJson(
                riverEntry.value as Map<String, dynamic>,
              ),
          },
      },
    );
  }
}

/// ターン・リバーの代表カード1枚における、ハンドクラス別 c-bet 頻度
/// （オリジナルの `oop_first` ノードのみ。相手のベットに直面した場合の
/// 応答ノードはこの画面ではまだ扱わない）。
class GtoStreetNode {
  const GtoStreetNode({required this.card, required this.betByCode});

  final PlayingCard card;
  final Map<String, double> betByCode;

  double? betFor(String code) => betByCode[code];

  factory GtoStreetNode.fromJson(Map<String, dynamic> json) {
    final nodes = json['nodes'] as Map<String, dynamic>? ?? const {};
    final oopFirst = nodes['oop_first'] as Map<String, dynamic>? ?? const {};
    return GtoStreetNode(
      card: PlayingCard.parse(json['card'] as String),
      betByCode: {
        for (final entry in oopFirst.entries)
          entry.key: _totalBetFrequency(entry.value as Map<String, dynamic>),
      },
    );
  }
}

double _totalBetFrequency(Map<String, dynamic> row) {
  var total = 0.0;
  for (final entry in row.entries) {
    if (entry.key == 'combos' || entry.key == 'x') continue;
    total += (entry.value as num).toDouble();
  }
  return total;
}
