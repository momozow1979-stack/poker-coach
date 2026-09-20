import '../../../shared/models/playing_card.dart';

/// `/read-hand`(Claude Vision)が推定したカード1枚分の役割。
enum ReadCardRole {
  me('me'),
  board('board'),
  villain('villain');

  const ReadCardRole(this.id);

  final String id;

  static ReadCardRole fromId(String id) => ReadCardRole.values.firstWhere(
    (role) => role.id == id,
    orElse: () => ReadCardRole.board,
  );
}

/// 写真から読み取った1枚。ランク・スートは正確に読めている前提だが、
/// [confidence] が低い場合はユーザーに確認を促す。
class ReadHandCard {
  const ReadHandCard({
    required this.card,
    required this.confidence,
    required this.suggested,
    this.boardOrder,
    this.cluster,
  });

  final PlayingCard card;
  final double confidence;
  final ReadCardRole suggested;

  /// 場のカードの並び順（右端が1＝フロップ1枚目）。場のときだけ入る。
  final int? boardOrder;

  /// 相手の人ごとのまとまり（1 から）。相手のときだけ入る。
  final int? cluster;

  static ReadHandCard? tryFromJson(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is! String) return null;
    final PlayingCard parsed;
    try {
      parsed = PlayingCard.parse(_normalize(code));
    } on FormatException {
      return null;
    } on StateError {
      // 未知のランク/スート記号は firstWhere が StateError を投げる。
      return null;
    }
    return ReadHandCard(
      card: parsed,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      suggested: ReadCardRole.fromId(json['suggested'] as String? ?? 'board'),
      boardOrder: (json['board_order'] as num?)?.toInt(),
      cluster: (json['cluster'] as num?)?.toInt(),
    );
  }

  /// `10x` を `Tx` に寄せるなどの軽い正規化。
  static String _normalize(String code) {
    if (code.length == 3 && code.startsWith('10')) return 'T${code[2]}';
    return code;
  }
}

/// `/read-hand` のレスポンス全体。
class ReadHandResult {
  const ReadHandResult({required this.cards, this.warnings = const []});

  final List<ReadHandCard> cards;
  final List<String> warnings;

  factory ReadHandResult.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    final cards = <ReadHandCard>[];
    if (rawCards is List) {
      for (final raw in rawCards) {
        if (raw is Map<String, dynamic>) {
          final card = ReadHandCard.tryFromJson(raw);
          if (card != null) cards.add(card);
        }
      }
    }
    final rawWarnings = json['warnings'];
    final warnings = <String>[
      if (rawWarnings is List)
        for (final w in rawWarnings)
          if (w is String) w,
    ];
    return ReadHandResult(cards: cards, warnings: warnings);
  }
}
