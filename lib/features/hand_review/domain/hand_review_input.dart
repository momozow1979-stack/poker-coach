import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';

/// キャッシュ / トーナメントの別。
enum GameType {
  cash('cash', 'Cash'),
  tournament('tournament', 'Tournament');

  const GameType(this.id, this.label);

  final String id;
  final String label;

  static GameType fromId(String id) =>
      GameType.values.firstWhere((type) => type.id == id, orElse: () => cash);
}

/// 相手の傾向。実戦調整の解説を切り替えるために使う。
enum VillainProfile {
  unknown('unknown', 'Unknown'),
  tight('tight', 'Tight'),
  loose('loose', 'Loose'),
  passive('passive', 'Passive'),
  aggressive('aggressive', 'Aggressive');

  const VillainProfile(this.id, this.label);

  final String id;
  final String label;

  static VillainProfile fromId(String id) => VillainProfile.values.firstWhere(
    (profile) => profile.id == id,
    orElse: () => unknown,
  );
}

/// プレイ環境。
enum PlayEnvironment {
  online('online', 'Online'),
  live('live', 'Live');

  const PlayEnvironment(this.id, this.label);

  final String id;
  final String label;

  static PlayEnvironment fromId(String id) => PlayEnvironment.values.firstWhere(
    (environment) => environment.id == id,
    orElse: () => online,
  );
}

/// ポストフロップ 1 ストリート分の入力。
class StreetInput {
  const StreetInput({this.cards = const [], this.actions = const []});

  final List<PlayingCard> cards;
  final List<HandAction> actions;

  bool get isEmpty => cards.isEmpty && actions.isEmpty;

  StreetInput copyWith({List<PlayingCard>? cards, List<HandAction>? actions}) =>
      StreetInput(cards: cards ?? this.cards, actions: actions ?? this.actions);
}

/// `hero_position` のような、保存済み JSON からのポジション復元。
Position _positionFromLabel(Object? label, Position fallback) {
  if (label is! String) return fallback;
  try {
    return Position.fromLabel(label);
  } on StateError {
    return fallback;
  }
}

List<PlayingCard> _cardsFrom(Object? value) {
  if (value is! List) return const [];
  final cards = <PlayingCard>[];
  for (final code in value) {
    if (code is! String) continue;
    try {
      cards.add(PlayingCard.parse(code));
    } on Exception {
      // 壊れた保存データで履歴全体が読めなくならないよう、その 1 枚だけ捨てる。
    }
  }
  return cards;
}

List<HandAction> _actionsFrom(Object? value) => [
  if (value is List)
    for (final action in value)
      if (action is Map<String, dynamic>) HandAction.fromJson(action),
];

/// ハンドレビューの入力。仕様書 5-2 の JSON と 1 対 1 で対応する。
class HandReviewInput {
  const HandReviewInput({
    this.gameType = GameType.cash,
    this.tableType = TableType.sixMax,
    this.effectiveStackBb,
    this.heroPosition = Position.btn,
    this.heroHand = const [],
    this.villainPosition = Position.bb,
    this.villainHand = const [],
    this.villainProfile = VillainProfile.unknown,
    this.environment = PlayEnvironment.online,
    this.preflop = const [],
    this.flop = const StreetInput(),
    this.turn = const StreetInput(),
    this.river = const StreetInput(),
    this.userQuestion = '',
  });

  final GameType gameType;
  final TableType tableType;

  /// 有効スタック（BB 単位）。分からなければ null。
  ///
  /// ブラインドの実額は持たない。アプリの中はすべて BB 単位で動いており、
  /// 「SB 50 / BB 100」のような実額はどこの計算にも使われないため。
  final double? effectiveStackBb;

  final Position heroPosition;
  final List<PlayingCard> heroHand;
  final Position villainPosition;

  /// 相手の 2 枚。ショーダウンで見えたときだけ入る。分からなければ空。
  final List<PlayingCard> villainHand;
  final VillainProfile villainProfile;
  final PlayEnvironment environment;
  final List<HandAction> preflop;
  final StreetInput flop;
  final StreetInput turn;
  final StreetInput river;

  /// 「自分が迷ったポイント」。任意入力。
  final String userQuestion;

  /// フロップ以降のボード全体。
  List<PlayingCard> get board => [...flop.cards, ...turn.cards, ...river.cards];

  /// [street] でこのハンドに追加されるボードカード。
  List<PlayingCard> boardOf(Street street) => switch (street) {
    Street.preflop => const [],
    Street.flop => flop.cards,
    Street.turn => turn.cards,
    Street.river => river.cards,
  };

  /// [street] のアクション。
  List<HandAction> actionsOf(Street street) => switch (street) {
    Street.preflop => preflop,
    Street.flop => flop.actions,
    Street.turn => turn.actions,
    Street.river => river.actions,
  };

  /// [street] までに開いているボード全体。
  List<PlayingCard> boardUpTo(Street street) => switch (street) {
    Street.preflop => const [],
    Street.flop => flop.cards,
    Street.turn => [...flop.cards, ...turn.cards],
    Street.river => [...flop.cards, ...turn.cards, ...river.cards],
  };

  /// 使用済みのカード。カードピッカーで重複を防ぐために使う。
  Set<PlayingCard> get usedCards => {...heroHand, ...villainHand, ...board};

  /// 到達した最終ストリートの名前。
  String get lastStreetLabel {
    if (river.cards.isNotEmpty) return 'リバー';
    if (turn.cards.isNotEmpty) return 'ターン';
    if (flop.cards.isNotEmpty) return 'フロップ';
    return 'プリフロップ';
  }

  HandReviewInput copyWith({
    GameType? gameType,
    TableType? tableType,
    double? effectiveStackBb,
    bool clearEffectiveStack = false,
    Position? heroPosition,
    List<PlayingCard>? heroHand,
    Position? villainPosition,
    List<PlayingCard>? villainHand,
    VillainProfile? villainProfile,
    PlayEnvironment? environment,
    List<HandAction>? preflop,
    StreetInput? flop,
    StreetInput? turn,
    StreetInput? river,
    String? userQuestion,
  }) {
    return HandReviewInput(
      gameType: gameType ?? this.gameType,
      tableType: tableType ?? this.tableType,
      effectiveStackBb: clearEffectiveStack
          ? null
          : effectiveStackBb ?? this.effectiveStackBb,
      heroPosition: heroPosition ?? this.heroPosition,
      heroHand: heroHand ?? this.heroHand,
      villainPosition: villainPosition ?? this.villainPosition,
      villainHand: villainHand ?? this.villainHand,
      villainProfile: villainProfile ?? this.villainProfile,
      environment: environment ?? this.environment,
      preflop: preflop ?? this.preflop,
      flop: flop ?? this.flop,
      turn: turn ?? this.turn,
      river: river ?? this.river,
      userQuestion: userQuestion ?? this.userQuestion,
    );
  }

  /// [toJson] で書き出した JSON から復元する。保存済み履歴の読み戻しに使う。
  factory HandReviewInput.fromJson(Map<String, dynamic> json) {
    final turnCard = json['turn'] is Map<String, dynamic>
        ? (json['turn'] as Map<String, dynamic>)['card']
        : null;
    final riverCard = json['river'] is Map<String, dynamic>
        ? (json['river'] as Map<String, dynamic>)['card']
        : null;
    final flop = json['flop'] as Map<String, dynamic>? ?? const {};

    return HandReviewInput(
      gameType: GameType.fromId(json['game_type'] as String? ?? ''),
      tableType: TableType.values.firstWhere(
        (type) => type.id == json['table_type'],
        orElse: () => TableType.sixMax,
      ),
      effectiveStackBb: (json['effective_stack_bb'] as num?)?.toDouble(),
      heroPosition: _positionFromLabel(json['hero_position'], Position.btn),
      heroHand: _cardsFrom(json['hero_hand']),
      villainPosition: _positionFromLabel(
        json['villain_position'],
        Position.bb,
      ),
      villainHand: _cardsFrom(json['villain_hand']),
      villainProfile: VillainProfile.fromId(
        json['villain_profile'] as String? ?? '',
      ),
      environment: PlayEnvironment.fromId(json['environment'] as String? ?? ''),
      preflop: _actionsFrom(json['preflop']),
      flop: StreetInput(
        cards: _cardsFrom(flop['board']),
        actions: _actionsFrom(flop['actions']),
      ),
      turn: StreetInput(
        cards: _cardsFrom(turnCard == null ? const [] : [turnCard]),
        actions: _actionsFrom(
          json['turn'] is Map<String, dynamic>
              ? (json['turn'] as Map<String, dynamic>)['actions']
              : null,
        ),
      ),
      river: StreetInput(
        cards: _cardsFrom(riverCard == null ? const [] : [riverCard]),
        actions: _actionsFrom(
          json['river'] is Map<String, dynamic>
              ? (json['river'] as Map<String, dynamic>)['actions']
              : null,
        ),
      ),
      userQuestion: json['user_question'] as String? ?? '',
    );
  }

  /// Edge Function `POST /review` へ送る JSON。仕様書 5-2 の形式。
  Map<String, dynamic> toJson() => {
    'game_type': gameType.id,
    'table_type': tableType.id,
    if (effectiveStackBb != null) 'effective_stack_bb': effectiveStackBb,
    'hero_position': heroPosition.label,
    'hero_hand': PlayingCard.encodeAll(heroHand),
    'villain_position': villainPosition.label,
    if (villainHand.isNotEmpty)
      'villain_hand': PlayingCard.encodeAll(villainHand),
    'villain_profile': villainProfile.id,
    'environment': environment.id,
    'preflop': [for (final action in preflop) action.toJson()],
    'flop': {
      'board': PlayingCard.encodeAll(flop.cards),
      'actions': [for (final action in flop.actions) action.toJson()],
    },
    'turn': {
      'card': turn.cards.isEmpty ? null : turn.cards.first.code,
      'actions': [for (final action in turn.actions) action.toJson()],
    },
    'river': {
      'card': river.cards.isEmpty ? null : river.cards.first.code,
      'actions': [for (final action in river.actions) action.toJson()],
    },
    'user_question': userQuestion,
  };
}
