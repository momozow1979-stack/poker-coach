import '../../../shared/models/position.dart';
import '../../../shared/models/table_type.dart';
import '../domain/range_action.dart';
import '../domain/range_spot.dart';

/// 境界線上のハンドをどの 2 アクションで・どの割合で混ぜるか。
///
/// [RangeDefinition.notationByAction] が適用された後、最後に適用される
/// （そのハンドの最終アクションは常に [RangeAction.mixed] になる）。
/// 割合はソルバーの厳密な出力ではなく、学習用に整理した目安の値。
class MixedRangeGroup {
  const MixedRangeGroup({
    required this.notation,
    required this.primary,
    required this.primaryShare,
    required this.secondary,
  });

  /// レンジ表記（`22+, ATs+` など）。
  final String notation;

  /// より頻度の高いアクション。
  final RangeAction primary;

  /// [primary] を取る割合（0.0〜1.0）。
  final double primaryShare;

  /// 残りの割合で取るアクション。
  final RangeAction secondary;
}

/// 1 つのスポットのレンジ定義。
///
/// ハンドはレンジ表記（`22+, ATs+` など）で保持し、表示時に 169 ハンドへ展開する。
class RangeDefinition {
  const RangeDefinition({
    required this.spot,
    required this.notationByAction,
    this.mixedGroups = const [],
  });

  final RangeSpot spot;

  /// アクションごとのレンジ表記。後ろのアクションが前を上書きする。
  final Map<RangeAction, String> notationByAction;

  /// 境界線上のハンド（複数グループ可）。[notationByAction] より後に、
  /// 常に最後に適用される。
  final List<MixedRangeGroup> mixedGroups;
}

/// MVP で同梱するレンジ定義。
///
/// 数値はソルバー出力そのものではなく、初心者が覚えやすいように整理した学習用の目安。
/// vsOpen シナリオ（`_vsOpen` で作った定義）も含め、標準的なプリフロップ理論に
/// 基づく手作業の目安であり、厳密な頻度を主張するものではない。
abstract final class RangeDefinitions {
  static const double _defaultStackBb = 100;

  static List<RangeDefinition> get all => [..._sixMax, ..._nineMax];

  /// [tableType] / [position] に対応する定義を探す。
  ///
  /// [situation] を省略した場合、そのポジションの最初に登録された定義
  /// （オープンレイズがあればそれ、無ければ唯一の定義）を返す。これは
  /// vsOpen 定義が増える前の挙動と完全に一致する（後方互換）。
  /// [situation] を明示した場合、そのポジションにそのシチュエーションの
  /// 定義が無ければ null を返す。
  static RangeDefinition? find(
    TableType tableType,
    Position position, [
    RangeSituation? situation,
  ]) {
    final matches = _forPosition(tableType, position);
    if (matches.isEmpty) return null;
    if (situation == null) return matches.first;
    for (final definition in matches) {
      if (definition.spot.situation == situation) return definition;
    }
    return null;
  }

  /// [tableType] / [position] に登録されているシチュエーション一覧。
  ///
  /// 複数ある場合のみ、画面側で切り替え UI を出す判断に使う。
  static List<RangeSituation> situationsFor(
    TableType tableType,
    Position position,
  ) => [
    for (final definition in _forPosition(tableType, position))
      definition.spot.situation,
  ];

  static List<RangeDefinition> _forPosition(
    TableType tableType,
    Position position,
  ) => [
    for (final definition in all)
      if (definition.spot.tableType == tableType &&
          definition.spot.heroPosition == position)
        definition,
  ];

  static RangeDefinition _openRaise({
    required TableType tableType,
    required Position position,
    required String raise,
    String mixed = '',
    required String headline,
  }) {
    return RangeDefinition(
      spot: RangeSpot(
        id: '${tableType.id}_${position.label.toLowerCase()}_open',
        tableType: tableType,
        situation: RangeSituation.openRaise,
        heroPosition: position,
        stackBb: _defaultStackBb,
        title: '${tableType.label} / ${position.label} オープンレイズ',
        headline: headline,
      ),
      notationByAction: {RangeAction.raise: raise},
      mixedGroups: [
        MixedRangeGroup(
          notation: mixed,
          primary: RangeAction.raise,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    );
  }

  static RangeDefinition _bbDefense(TableType tableType) {
    return RangeDefinition(
      spot: RangeSpot(
        id: '${tableType.id}_bb_defense',
        tableType: tableType,
        situation: RangeSituation.vsOpen,
        heroPosition: Position.bb,
        villainPosition: Position.btn,
        stackBb: _defaultStackBb,
        title: '${tableType.label} / BB ディフェンス vs BTN オープン',
        headline: 'BB は自分からオープンできないポジション。BTN の 2.5BB オープンに対する守り方を確認しましょう。',
      ),
      notationByAction: {
        RangeAction.threeBet: '99+, AJs+, KQs, A5s-A4s, AQo+',
        RangeAction.call:
            '22-88, A2s+, K2s+, Q5s+, J7s+, T7s+, 96s+, 85s+, 75s+, 64s+, 53s+, '
            'A2o+, K8o+, Q9o+, J9o+, T9o, 98o',
      },
      mixedGroups: [
        MixedRangeGroup(
          notation: 'K7o, Q8o, J8o, T8o, 87o, 76o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    );
  }

  /// 直前のポジションのオープンに対して 3Bet / Call / Fold で応じるシナリオ。
  ///
  /// BB のディフェンス（[_bbDefense]）と同じ考え方で、「一番典型的に対面する
  /// 相手」として直近のオープンポジションを 1 つだけ相手にする。標準的な
  /// プリフロップ理論に基づく学習用の目安であり、ソルバー出力ではない。
  static RangeDefinition _vsOpen({
    required TableType tableType,
    required Position position,
    required Position villain,
    required String call,
    required String threeBet,
    required String headline,
    List<MixedRangeGroup> mixedGroups = const [],
  }) {
    return RangeDefinition(
      spot: RangeSpot(
        id: '${tableType.id}_${position.label.toLowerCase()}_defense',
        tableType: tableType,
        situation: RangeSituation.vsOpen,
        heroPosition: position,
        villainPosition: villain,
        stackBb: _defaultStackBb,
        title:
            '${tableType.label} / ${position.label} ディフェンス vs ${villain.label} オープン',
        headline: headline,
      ),
      // call を先に、threeBet を後に置く。レンジ表記の "+" 表現は上限側に
      // 余分に広がることがあるため（例: A2s+ は AKs まで含む）、後で処理される
      // アクションを勝たせることで「価値の強いアクションが優先される」という
      // 直感的な優先順位にしている。境界のハンドは mixedGroups で明示するため、
      // ここでの多少の重なりは最終結果に影響しない。
      notationByAction: {
        RangeAction.call: call,
        RangeAction.threeBet: threeBet,
      },
      mixedGroups: mixedGroups,
    );
  }

  // ---------------------------------------------------------------- 6MAX ----

  static final List<RangeDefinition> _sixMax = [
    _openRaise(
      tableType: TableType.sixMax,
      position: Position.utg,
      headline: '後ろに 5 人残っている一番不利な席。強いハンドに絞ります。',
      raise: '55+, A9s+, KTs+, QTs+, J9s+, T9s, 98s, AJo+, KQo',
      mixed: '44, A8s, K9s, 87s, ATo',
    ),
    _openRaise(
      tableType: TableType.sixMax,
      position: Position.hj,
      headline: 'UTG より少しだけ広げられます。まだ後ろに 4 人います。',
      raise:
          '44+, A7s+, A5s-A4s, K9s+, Q9s+, J9s+, T8s+, 97s+, 87s, ATo+, KJo+',
      mixed: '33, A6s, K8s, Q8s, 76s, KTo, QJo',
    ),
    _vsOpen(
      tableType: TableType.sixMax,
      position: Position.hj,
      villain: Position.utg,
      headline:
          'UTG のオープンはこのアプリの中で最もタイトなレンジ。価値ハンドに絞って 3Bet し、'
          'それ以外はインポジションのコールで様子を見ます。',
      call: 'TT-77, AJs, KQs, KJs, QJs, JTs, T9s, 98s, AQo',
      threeBet: 'QQ+, AKs, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: 'JJ, AQs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '66-55, ATs, KTs, QTs, KQo',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.sixMax,
      position: Position.co,
      headline: '後ろは BTN とブラインドだけ。ここからレンジを大きく広げます。',
      raise: '22+, A2s+, K7s+, Q8s+, J8s+, T8s+, 97s+, 86s+, 76s, 65s, A9o+, KTo+, QTo+, JTo',
      mixed: 'K6s, Q7s, J7s, T7s, 54s, A8o, K9o, Q9o',
    ),
    _vsOpen(
      tableType: TableType.sixMax,
      position: Position.co,
      villain: Position.hj,
      headline:
          'HJ のオープンは UTG より広がっています。3Bet の価値レンジを少し広げつつ、'
          'コールレンジも増やして対応します。',
      call: '99-66, ATs, KQs, KJs, QJs, JTs, T9s, 98s, 87s, AJo, KQo',
      threeBet: 'JJ+, AQs, AKs, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: 'TT, AJs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '55-44, A9s, KTs, QTs, JTo',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.sixMax,
      position: Position.btn,
      headline: '最も有利な席。ポストフロップで常に最後に動けるので、かなり広く戦えます。',
      raise:
          '22+, A2s+, K2s+, Q4s+, J6s+, T6s+, 95s+, 85s+, 74s+, 64s+, 53s+, '
          'A2o+, K7o+, Q8o+, J8o+, T8o+, 98o, 87o, 76o',
      mixed: 'Q3s, J5s, T5s, 94s, 84s, 63s, 43s, K6o, Q7o, J7o, 65o',
    ),
    _vsOpen(
      tableType: TableType.sixMax,
      position: Position.btn,
      villain: Position.co,
      headline:
          '一番有利な BTN。CO のオープンは広いので、ブロッカー系のブラフ 3Bet（A5s-A2s）を '
          '交えて積極的に対応します。',
      call: '88-55, ATs, A9s, KJs, KTs, QJs, QTs, JTs, T9s, 98s, 87s, AJo, KJo',
      threeBet: 'TT+, AQs, AKs, A5s-A2s, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, AJs, KQo',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '44, A8s, K9s, Q9s, J9o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.sixMax,
      position: Position.sb,
      headline: 'BB とのヘッズアップ。広く入れますが、ポストフロップは常に不利です。',
      raise:
          '22+, A2s+, K5s+, Q6s+, J7s+, T7s+, 96s+, 86s+, 75s+, 65s, 54s, '
          'A4o+, K9o+, Q9o+, J9o+, T9o',
      mixed: 'K4s, Q5s, J6s, T6s, A2o, A3o, K8o, Q8o, J8o',
    ),
    _vsOpen(
      tableType: TableType.sixMax,
      position: Position.sb,
      villain: Position.btn,
      headline:
          'SB はブラインド対決の中でも一番難しい席。BTN のオープンは広いものの、'
          'BB がまだ後ろに残っているぶん、BB のディフェンスより少し引き締めて対応します。',
      call:
          '22-88, A2s+, K5s+, Q8s+, J8s+, T8s+, 97s+, 86s+, '
          'A2o+, K9o+, Q9o+, J9o+, T9o',
      threeBet: 'TT+, AJs+, KQs, AQo+',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, KJs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: 'K4s, Q7s, J7s, T7s, 76s, 87o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _bbDefense(TableType.sixMax),
  ];

  // ---------------------------------------------------------------- 9MAX ----

  static final List<RangeDefinition> _nineMax = [
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.utg,
      headline: '9人テーブルで最も不利な席。ほぼプレミアムハンドだけで戦います。',
      raise: '77+, ATs+, KJs+, QJs, JTs, AQo+',
      mixed: '66, A9s, KTs, T9s, AJo, KQo',
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.utg1,
      headline: 'UTG とほぼ同じ考え方。まだ 7 人が後ろにいます。',
      raise: '66+, A9s+, KTs+, QTs+, JTs, T9s, AJo+, KQo',
      mixed: '55, A8s, K9s, 98s, ATo, KJo',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.utg1,
      villain: Position.utg,
      headline:
          'UTG のオープンは 9MAX で最もタイト。ほぼ価値のみで 3Bet し、それ以外は絞った '
          'コールに留めます。',
      call: 'TT-88, AJs, KQs, KJs, QJs',
      threeBet: 'QQ+, AKs, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: 'JJ, AQs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '77, ATs, AQo',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.mp,
      headline: '少しだけ広げられますが、まだアーリー寄りの席です。',
      raise: '55+, A8s+, KTs+, Q9s+, J9s+, T9s, 98s, AJo+, KQo',
      mixed: '44, A7s, A5s, K9s, 87s, ATo, KJo',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.mp,
      villain: Position.utg1,
      headline:
          'UTG+1 のオープンも依然タイト。価値中心の 3Bet に、コールレンジを少しだけ '
          '広げて対応します。',
      call: 'TT-77, AJs, ATs, KQs, KJs, QJs, JTs',
      threeBet: 'QQ+, AKs, AKo, AQo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: 'JJ, AQs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '66, KQo, T9s',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.lj,
      headline: 'ここからミドル〜レイト。スーテッドハンドを足していきます。',
      raise: '44+, A7s+, A5s-A4s, K9s+, Q9s+, J9s+, T8s+, 98s, ATo+, KJo+',
      mixed: '33, A6s, K8s, Q8s, 87s, 76s, KTo, QJo',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.lj,
      villain: Position.mp,
      headline:
          'MP のオープンは少し広がります。3Bet の価値レンジを保ちつつ、コールレンジも '
          '一段広げます。',
      call: '99-66, ATs, KQs, KJs, QJs, JTs, T9s, KQo',
      threeBet: 'JJ+, AQs, AKs, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: 'TT, AJs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '55, A9s, K9s, JTo',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.hj,
      headline: '後ろは 4 人。コネクター類も参加できるようになります。',
      raise:
          '33+, A5s+, K8s+, Q9s+, J9s+, T8s+, 97s+, 87s, 76s, ATo+, KJo+, QJo',
      mixed: '22, A4s, A3s, K7s, Q8s, J8s, 65s, A9o, KTo, QTo',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.hj,
      villain: Position.lj,
      headline:
          'LJ のオープンは中間レンジ。ブロッカー系のブラフ（A5s-A4s）を 3Bet に '
          '混ぜ始めます。',
      call: '88-66, ATs, A9s, KJs, KTs, QJs, QTs, JTs, T9s, 98s, KQo',
      threeBet: 'TT+, AQs, AKs, A5s-A4s, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, AJs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '55, K9s, Q9s, JTo, T9o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.co,
      headline: '後ろは BTN とブラインドだけ。ここから一気に広げます。',
      raise: '22+, A2s+, K7s+, Q8s+, J8s+, T8s+, 97s+, 86s+, 76s, 65s, A9o+, KTo+, QTo+, JTo',
      mixed: 'K6s, Q7s, J7s, T7s, 54s, A8o, K9o, Q9o',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.co,
      villain: Position.hj,
      headline:
          'HJ のオープンはさらに広がります。ブロッカー 3Bet の範囲を広げ、コールレンジ '
          'も厚くします。',
      call: '88-55, ATs, A9s, KJs, KTs, QJs, QTs, JTs, T9s, 98s, 87s, AJo, KQo',
      threeBet: 'TT+, AQs, AKs, A5s-A2s, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, AJs, KQs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '44, A8s, K9s, Q9s, J9s, JTo',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.btn,
      headline: '最も有利な席。9MAX でも BTN のレンジは 6MAX とほぼ同じです。',
      raise:
          '22+, A2s+, K2s+, Q4s+, J6s+, T6s+, 95s+, 85s+, 74s+, 64s+, 53s+, '
          'A2o+, K7o+, Q8o+, J8o+, T8o+, 98o, 87o, 76o',
      mixed: 'Q3s, J5s, T5s, 94s, 84s, 63s, 43s, K6o, Q7o, J7o, 65o',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.btn,
      villain: Position.co,
      headline:
          '最も有利な BTN。CO のオープンは広いので、ブロッカー 3Bet を増やし、コール '
          'レンジも広く取ります。',
      call: '88-55, ATs, A9s, KJs, KTs, QJs, QTs, JTs, T9s, 98s, 87s, AJo, KJo',
      threeBet: 'TT+, AQs, AKs, A5s-A2s, KQs, AQo, AKo',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, AJs, KQo',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: '44, A8s, K9s, Q9s, J9o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _openRaise(
      tableType: TableType.nineMax,
      position: Position.sb,
      headline: 'BB とのヘッズアップ。広く入れますが、ポストフロップは常に不利です。',
      raise:
          '22+, A2s+, K5s+, Q6s+, J7s+, T7s+, 96s+, 86s+, 75s+, 65s, 54s, '
          'A4o+, K9o+, Q9o+, J9o+, T9o',
      mixed: 'K4s, Q5s, J6s, T6s, A2o, A3o, K8o, Q8o, J8o',
    ),
    _vsOpen(
      tableType: TableType.nineMax,
      position: Position.sb,
      villain: Position.btn,
      headline:
          'SB は BB が後ろに残っているブラインド対決。BTN のオープンは広いですが、'
          '9MAX でも 6MAX と同様に少し引き締めて対応します。',
      call:
          '22-88, A2s+, K5s+, Q8s+, J8s+, T8s+, 97s+, 86s+, '
          'A2o+, K9o+, Q9o+, J9o+, T9o',
      threeBet: 'TT+, AJs+, KQs, AQo+',
      mixedGroups: const [
        MixedRangeGroup(
          notation: '99, KJs',
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
        MixedRangeGroup(
          notation: 'K4s, Q7s, J7s, T7s, 76s, 87o',
          primary: RangeAction.call,
          primaryShare: 0.5,
          secondary: RangeAction.fold,
        ),
      ],
    ),
    _bbDefense(TableType.nineMax),
  ];
}
