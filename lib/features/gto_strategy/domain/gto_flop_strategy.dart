import '../../../shared/models/playing_card.dart';

/// ソルバー（`solver/`）で学習した、フロップ以降の戦略。
///
/// `solver/solve_srp_btn_bb.py` の出力（`assets/gto/solved_srp_btn_bb.json`）を
/// 読み込んだもの。各数値は `CFRSolver.average_strategy()` の読み出しを 169 の
/// スターティングハンドクラスへ平均した行動頻度で、捏造・推測は無い。
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

/// 1つのフロップ（3枚）についての、意思決定ノード別ハンドクラス行動頻度。
class GtoFlopSpot {
  const GtoFlopSpot({
    required this.id,
    required this.board,
    this.nodes = const {},
    this.turns = const {},
    this.rivers = const {},
  });

  final String id;
  final List<PlayingCard> board;

  /// フロップの意思決定ノード全て（OOPの最初の手番から、チェック後の
  /// IPの手番、各サイズのベットに直面した側の応答、レイズに直面した
  /// 代表例まで、ソルバーが実際に読み出した分すべて）。
  /// キーは `_nodeOrder`（プレゼンテーション層）参照。
  final Map<String, GtoActionNode> nodes;

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

  /// `solver/solve_srp_btn_bb.py` の出力は、1つの街（フロップ/ターン/リバー）
  /// につき最大12個の意思決定ノード（`_STREET_NODES`参照。OOPの最初の手番、
  /// チェック後のIPの手番、各ベットサイズに直面した側の応答、レイズに
  /// 直面した場合）を持つ。ここではその全てをパースする。
  factory GtoFlopSpot.fromJson(Map<String, dynamic> json) {
    final flop = json['flop'] as Map<String, dynamic>? ?? const {};
    final rawTurns = json['turns'] as Map<String, dynamic>? ?? const {};
    final rawRivers = json['rivers'] as Map<String, dynamic>? ?? const {};
    return GtoFlopSpot(
      id: json['id'] as String,
      board: PlayingCard.parseAll((json['board'] as List).cast<String>()),
      nodes: _parseActionNodes(flop),
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

/// ターン・リバーの代表カード1枚における、意思決定ノード全て。
class GtoStreetNode {
  const GtoStreetNode({required this.card, this.nodes = const {}});

  final PlayingCard card;

  /// この街の意思決定ノード全て。[GtoFlopSpot.nodes] と同じキー体系。
  final Map<String, GtoActionNode> nodes;

  factory GtoStreetNode.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as Map<String, dynamic>? ?? const {};
    return GtoStreetNode(
      card: PlayingCard.parse(json['card'] as String),
      nodes: _parseActionNodes(rawNodes),
    );
  }
}

/// `solve_srp_btn_bb.py` の `_STREET_NODES` と対になる、ノード名ごとの
/// 「おとなしい行動」記号。ヒートマップの色は「それ以外の合計」＝
/// 積極的な行動の頻度として揃えるため、ノードの種類ごとに意味が変わる
/// （チェックするか／ベットするか、か、降りるか／降りないか、か）。
const _passiveActionByNode = {
  'oop_first': 'x',
  'ip_vs_check': 'x',
  'ip_vs_bet_1': 'f',
  'ip_vs_bet_2': 'f',
  'ip_vs_bet_3': 'f',
  'ip_vs_bet_4': 'f',
  'oop_vs_checkbet_1': 'f',
  'oop_vs_checkbet_2': 'f',
  'oop_vs_checkbet_3': 'f',
  'oop_vs_checkbet_4': 'f',
  'oop_vs_raise': 'f',
  'ip_vs_raise_after_check': 'f',
};

Map<String, GtoActionNode> _parseActionNodes(Map<String, dynamic> streetJson) {
  return {
    for (final entry in streetJson.entries)
      if (_passiveActionByNode.containsKey(entry.key))
        entry.key: GtoActionNode.fromJson(
          entry.value as Map<String, dynamic>,
          passiveAction: _passiveActionByNode[entry.key]!,
        ),
  };
}

/// 1つの意思決定ノード（例:「フロップでOOPが最初に動く」「IPの1/2ポット
/// ベットにOOPが応じる」）における、ハンドクラス別の行動頻度。
///
/// 行動記号は `'x'`（チェック）・`'f'`（フォールド）・`'c'`（コール）・
/// `'1'`〜`'4'`（ベット/レイズの4段階、`BET_FRACTIONS`の1/3・1/2・2/3・
/// 1.5倍オーバーベットに対応）。ノードの種類によって使われる記号の組が
/// 異なるため、どの記号が並ぶかは [frequencies] の中身を見て判断する。
class GtoActionNode {
  const GtoActionNode({required this.frequencies, required this.passiveAction});

  final Map<String, Map<String, double>> frequencies;

  /// このノードでの「おとなしい行動」（チェック or フォールド）の記号。
  final String passiveAction;

  /// [code] の行動ごとの頻度。データが無ければ null。
  Map<String, double>? actionsFor(String code) => frequencies[code];

  /// [passiveAction] 以外の合計＝「積極的に行動する」頻度
  /// （チェック以外ならベット、フォールド以外ならコール+レイズ）。
  double? aggressionFor(String code) {
    final row = frequencies[code];
    if (row == null) return null;
    var total = 0.0;
    for (final entry in row.entries) {
      if (entry.key == passiveAction) continue;
      total += entry.value;
    }
    return total;
  }

  factory GtoActionNode.fromJson(
    Map<String, dynamic> json, {
    required String passiveAction,
  }) {
    return GtoActionNode(
      passiveAction: passiveAction,
      frequencies: {
        for (final entry in json.entries)
          entry.key: {
            for (final action in (entry.value as Map<String, dynamic>).entries)
              if (action.key != 'combos')
                action.key: (action.value as num).toDouble(),
          },
      },
    );
  }
}
