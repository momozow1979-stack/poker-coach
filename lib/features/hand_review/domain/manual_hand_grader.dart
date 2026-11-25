import '../../../shared/models/fast_hand_evaluator.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../practice_table/domain/grading/combo_equity.dart';
import '../../practice_table/domain/grading/decision_grade.dart';
import '../../range_chart/domain/range_action.dart';
import '../../range_chart/domain/range_entry.dart';
import '../../range_chart/domain/range_repository.dart';
import '../../range_chart/domain/range_spot.dart';
import 'hand_flow.dart';
import 'hand_read.dart';
import 'hand_review_input.dart';

/// 手入力したハンドの、ヒーローの 1 回の判断への採点。
class ManualDecisionGrade {
  const ManualDecisionGrade({
    required this.street,
    required this.actionLabel,
    required this.verdict,
    required this.headline,
    this.reasons = const [],
    this.numbers = const [],
    this.ifChanged,
  });

  final Street street;

  /// 「レイズ」「2.5BB へのコール」のような、何をした判断か。
  final String actionLabel;

  /// ○△×。計算で確かめられない判断は null（採点しない）。
  final PracticeVerdict? verdict;

  final String headline;
  final List<String> reasons;

  /// 根拠の数字（名前, 値）。
  final List<(String, String)> numbers;

  /// こうなら答えが変わる（AGENTS.md ルール5）。
  final String? ifChanged;
}

/// 手入力したハンドを、計算で確かめられる範囲だけ採点する。
///
/// 「AI相手に練習」と違って相手の打ち方が分からないので、次の 2 種類だけを
/// 採点する。どちらも数字は計算で出したもので、GTO の頻度は使わない。
///
/// 1. プリフロップの最初の判断: アプリ同梱のレンジ表の答えと比べる
///    （その席・その相手の組み合わせの表があるときだけ）。
/// 2. フロップ以降で賭けに直面した判断: 相手の範囲に対する勝率と、
///    ポットオッズから出る必要勝率を比べる。相手の範囲は
///    「プリフロップの行動に合うレンジ表の手」から、
///    「賭けた（レイズした）ストリートではペア以上かドローがあった」
///    という前提で絞り込む（この前提は画面でも明記する）。
///
/// 自分から賭けた判断は、相手が降りる割合が分からないので採点しない
/// （元が取れるのに必要な降りる割合だけを示す）。
class ManualHandGrader {
  const ManualHandGrader({required this.ranges});

  final RangeRepository ranges;

  /// 前後でこれだけ近いと、どちらの判断もありとして △ にする。
  static const closeMargin = 0.05;

  static const villainBetAssumption =
      '相手の範囲は、プリフロップの行動に合うレンジ表の手から、'
      '賭けた（レイズした）ストリートでは「ペア以上か、あと 1 枚で完成するドローが'
      'あった」という前提で絞り込んでいます。実際の相手の打ち方とは違うことがあります。';

  List<ManualDecisionGrade> grade(HandReviewInput input) {
    final flow = HandFlow(input);
    final grades = <ManualDecisionGrade>[];
    final preflop = _gradePreflop(input);
    if (preflop != null) grades.add(preflop);

    final villainRange = _villainPreflopRange(input);
    for (final faced in flow.heroFacedBets) {
      if (faced.street == Street.preflop) continue;
      grades.add(_gradeFacedBet(input, faced, villainRange));
    }
    for (final bet in flow.heroBets) {
      if (bet.street == Street.preflop) continue;
      final added = bet.addedBb;
      final needed = added / (bet.potBeforeBb + added);
      grades.add(
        ManualDecisionGrade(
          street: bet.street,
          actionLabel:
              '${bet.isRaise ? 'レイズ' : 'ベット'}（ポットの '
              '${(bet.potFraction * 100).round()}%）',
          verdict: null,
          headline: '自分から賭けた判断は採点していません',
          reasons: [
            '良し悪しは「相手がどれだけ降りるか・何で受けるか」で決まりますが、'
                '手入力のハンドでは相手の打ち方が分からないためです。',
          ],
          numbers: [('降ろすだけで元が取れる、相手の降りる割合', _pct(needed))],
          ifChanged:
              '相手が ${_pct(needed)} 以上降りる相手なら、手が弱くても'
              '（ブラフでも）この額で得になります。',
        ),
      );
    }
    grades.sort((a, b) => a.street.index.compareTo(b.street.index));
    return grades;
  }

  // ------------------------------------------------------------ プリフロップ

  /// ヒーローの最初の判断の前に、相手がレイズしていたか。
  static bool _villainOpenedFirst(HandReviewInput input) {
    for (final action in input.preflop) {
      if (action.isHero) return false;
      if (action.action.isAggressive) return true;
    }
    return false;
  }

  static HandAction? _heroFirst(HandReviewInput input) {
    for (final action in input.preflop) {
      if (action.isHero) return action;
    }
    return null;
  }

  ManualDecisionGrade? _gradePreflop(HandReviewInput input) {
    final first = _heroFirst(input);
    if (first == null || input.heroHand.length != 2) return null;
    final hand = StartingHand.fromCards(input.heroHand[0], input.heroHand[1]);
    final villainOpened = _villainOpenedFirst(input);
    final label = first.action.description;

    final chart = villainOpened
        ? _vsOpenChart(
            input.tableType,
            input.heroPosition,
            input.villainPosition,
          )
        : ranges.chartFor(
            input.tableType,
            input.heroPosition,
            situation: RangeSituation.openRaise,
          );
    if (chart == null) {
      return ManualDecisionGrade(
        street: Street.preflop,
        actionLabel: label,
        verdict: null,
        headline: 'この場面のレンジ表が無いため、採点していません',
        reasons: [
          villainOpened
              ? '${input.heroPosition.label} で ${input.villainPosition.label} の'
                    'オープンを受ける表は、まだアプリにありません。'
              : '${input.heroPosition.label} のオープンの表は、まだアプリにありません。',
        ],
      );
    }
    final entry = chart.entryFor(hand);
    final verdict = villainOpened
        ? _vsOpenVerdict(first.action, entry)
        : _openVerdict(first.action, entry.action);
    final answer = _answerText(entry, villainOpened: villainOpened);
    return ManualDecisionGrade(
      street: Street.preflop,
      actionLabel: label,
      verdict: verdict,
      headline: 'レンジ表の答え: $answer',
      reasons: [
        villainOpened
            ? '${hand.code} は、${input.heroPosition.label} で '
                  '${input.villainPosition.label} のオープンを受けるレンジ表で'
                  '「$answer」の手です。'
            : '${hand.code} は、${input.heroPosition.label} のオープンのレンジ表で'
                  '「$answer」の手です。',
      ],
      numbers: [
        (
          villainOpened ? 'この場面で参加する手の割合' : 'この席のオープンレンジの広さ',
          '${chart.vpipPercent.toStringAsFixed(1)}%',
        ),
      ],
      ifChanged: villainOpened
          ? '相手が表より広く（または狭く）オープンする人なら、受ける手も広げ（狭め）られます。'
          : '後ろの人たちがほとんど 3 ベットしてこないなら少し広げ、'
                'よく 3 ベットしてくるなら狭めます。',
    );
  }

  RangeChart? _vsOpenChart(
    TableType tableType,
    Position hero,
    Position villain,
  ) {
    final chart = ranges.chartFor(
      tableType,
      hero,
      situation: RangeSituation.vsOpen,
    );
    if (chart == null || chart.spot.villainPosition != villain) return null;
    return chart;
  }

  static PracticeVerdict _openVerdict(
    PokerActionType action,
    RangeAction table,
  ) {
    final plays = table == RangeAction.raise;
    final borderline = table == RangeAction.mixed;
    return switch (action) {
      PokerActionType.raise || PokerActionType.bet =>
        plays || borderline ? PracticeVerdict.good : PracticeVerdict.bad,
      PokerActionType.fold =>
        plays ? PracticeVerdict.bad : PracticeVerdict.good,
      PokerActionType.call || PokerActionType.check => PracticeVerdict.close,
      PokerActionType.allIn =>
        plays || borderline ? PracticeVerdict.close : PracticeVerdict.bad,
    };
  }

  static PracticeVerdict _vsOpenVerdict(
    PokerActionType action,
    RangeEntry entry,
  ) {
    final chosen = switch (action) {
      PokerActionType.fold => RangeAction.fold,
      PokerActionType.call || PokerActionType.check => RangeAction.call,
      PokerActionType.raise ||
      PokerActionType.bet ||
      PokerActionType.allIn => RangeAction.threeBet,
    };
    final allowed = entry.action == RangeAction.mixed
        ? {entry.blend?.primary, entry.blend?.secondary}
        : {entry.action};
    if (allowed.contains(chosen)) {
      // 100BB のオールインは表の想定外なので、3 ベットの手でも △ にとどめる。
      return action == PokerActionType.allIn
          ? PracticeVerdict.close
          : PracticeVerdict.good;
    }
    return PracticeVerdict.bad;
  }

  static String _answerText(RangeEntry entry, {required bool villainOpened}) {
    String name(RangeAction? action) => switch (action) {
      RangeAction.raise => 'レイズ',
      RangeAction.call => 'コール',
      RangeAction.threeBet => '3ベット',
      RangeAction.fourBet => '4ベット',
      RangeAction.fold || null => 'フォールド',
      RangeAction.mixed => '境目',
    };
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend;
      if (blend == null) {
        return villainOpened ? 'コールかフォールド（境目）' : 'レイズかフォールド（境目）';
      }
      return '${name(blend.primary)}か${name(blend.secondary)}（境目）';
    }
    return name(entry.action);
  }

  // ------------------------------------------------------- 相手の範囲・勝率

  /// プリフロップの行動に合う、相手の手の候補（組み合わせの一覧）。
  /// レンジ表が無い・リンプのポットなどで決められなければ null。
  List<StartingHand>? _villainPreflopRange(HandReviewInput input) {
    final villainOpened = _villainOpenedFirst(input);
    final raises = input.preflop.where((a) => a.action.isAggressive).toList();
    if (raises.isEmpty) return null;

    Set<RangeAction> want;
    RangeChart? chart;
    if (villainOpened && raises.length == 1) {
      // 相手がオープンし、あなたがコールした。
      chart = ranges.chartFor(
        input.tableType,
        input.villainPosition,
        situation: RangeSituation.openRaise,
      );
      want = {RangeAction.raise};
    } else if (!villainOpened && raises.length <= 2) {
      // あなたがオープンし、相手がコール（または 3 ベット）した。
      chart = _vsOpenChart(
        input.tableType,
        input.villainPosition,
        input.heroPosition,
      );
      want = raises.length == 1 ? {RangeAction.call} : {RangeAction.threeBet};
    } else {
      return null;
    }
    if (chart == null) return null;
    return [
      for (final hand in StartingHand.all)
        if (_plays(chart.entryFor(hand), want)) hand,
    ];
  }

  static bool _plays(RangeEntry entry, Set<RangeAction> want) {
    if (want.contains(entry.action)) return true;
    if (entry.action != RangeAction.mixed) return false;
    final blend = entry.blend;
    if (blend == null) return want.contains(RangeAction.raise);
    return want.contains(blend.primary) || want.contains(blend.secondary);
  }

  ManualDecisionGrade _gradeFacedBet(
    HandReviewInput input,
    FacedBet faced,
    List<StartingHand>? villainRange,
  ) {
    final label =
        '${faced.chosen.description}（${_bb(faced.toCallBb)}BB を払うかどうか）';
    final required = faced.requiredEquity;
    if (villainRange == null) {
      return ManualDecisionGrade(
        street: faced.street,
        actionLabel: label,
        verdict: null,
        headline: '相手の範囲を決められないため、採点していません',
        reasons: const [
          'プリフロップの流れ（席の組み合わせ・リンプ・4 ベットなど）に合う'
              'レンジ表がアプリにありません。',
        ],
        numbers: [('必要勝率（ポットオッズ）', _pct(required))],
        ifChanged:
            '自分の勝率が ${_pct(required)} 以上あると思えるならコール、'
            'それ未満ならフォールドが基本です。',
      );
    }

    final board = [
      for (final street in Street.values)
        if (street.index <= faced.street.index) ...input.boardOf(street),
    ];
    final known = {...input.heroHand, ...board};
    final combos = <List<PlayingCard>>[];
    for (final hand in villainRange) {
      for (final combo in _combosOf(hand)) {
        if (known.contains(combo[0]) || known.contains(combo[1])) continue;
        if (!_survivesVillainBets(input, combo, faced.street)) continue;
        combos.add(combo);
      }
    }
    if (combos.isEmpty) {
      return ManualDecisionGrade(
        street: faced.street,
        actionLabel: label,
        verdict: null,
        headline: '前提に合う相手の手が無いため、採点していません',
        numbers: [('必要勝率（ポットオッズ）', _pct(required))],
      );
    }
    final equity = ComboEquities.compute(
      hero: input.heroHand,
      board: board,
      combos: combos,
    ).mean;
    final draws = [
      for (final draw in HandRead.of(input.heroHand, board).draws)
        if (!draw.contains('バックドア')) draw,
    ];
    final canDraw = faced.street != Street.river;

    final PracticeVerdict? verdict;
    final String headline;
    switch (faced.chosen) {
      case PokerActionType.call:
        if (equity >= required) {
          verdict = PracticeVerdict.good;
          headline = '勝率が必要勝率を上回っているので、コールは得です';
        } else if (equity >= required - closeMargin ||
            (canDraw && draws.isNotEmpty)) {
          verdict = PracticeVerdict.close;
          headline = equity >= required - closeMargin
              ? '勝率と必要勝率がほぼ同じで、どちらもありの場面です'
              : '今の勝率では足りませんが、ドローが完成したときに後から取れる分'
                    '（インプライドオッズ）次第です';
        } else {
          verdict = PracticeVerdict.bad;
          headline = '勝率が必要勝率に届いていないので、コールは損です';
        }
      case PokerActionType.fold:
        if (equity < required - closeMargin) {
          verdict = PracticeVerdict.good;
          headline = '勝率が必要勝率に届いていないので、フォールドで正解です';
        } else if (equity < required + closeMargin) {
          verdict = PracticeVerdict.close;
          headline = '勝率と必要勝率がほぼ同じで、どちらもありの場面です';
        } else {
          verdict = PracticeVerdict.bad;
          headline = '勝率が必要勝率を上回っていたので、降りると損です';
        }
      case PokerActionType.raise || PokerActionType.allIn:
        // 勝ち越していないレイズ（ブラフ寄り）の良し悪しは、相手がどれだけ
        // 降りるかで決まり、手入力のハンドでは分からないので採点しない。
        verdict = equity >= 0.5 ? PracticeVerdict.good : null;
        headline = equity >= 0.5
            ? '相手の範囲に勝っている（勝率 50% 以上）ので、上乗せは筋が通ります'
            : '勝ち越していないレイズ（ブラフ寄り）は、相手がどれだけ降りるか次第で、'
                  'この計算だけでは決められません（採点していません）';
      case PokerActionType.check || PokerActionType.bet:
        verdict = null;
        headline = 'この判断は採点の対象外です';
    }

    return ManualDecisionGrade(
      street: faced.street,
      actionLabel: label,
      verdict: verdict,
      headline: headline,
      reasons: [
        'コールに ${_bb(faced.toCallBb)}BB、ポットは ${_bb(faced.potBb)}BB。'
            '払う額 ÷（ポット＋払う額）= 必要勝率 ${_pct(required)}。',
        '前提に合う相手の手 ${combos.length} 通りすべてに対して、'
            '残りのカードを数えたあなたの勝率は ${_pct(equity)}。',
        if (draws.isNotEmpty && canDraw) 'あなたのドロー: ${draws.join('、')}。',
      ],
      numbers: [
        ('必要勝率（ポットオッズ）', _pct(required)),
        ('相手の範囲に対するあなたの勝率', _pct(equity)),
        ('前提に合う相手の手', '${combos.length} 通り'),
      ],
      ifChanged: equity >= required
          ? '相手がもっと強い手でしか賭けない人なら、勝率は下がり、降りるのが良くなります。'
          : '相手がペア無しでもよく賭けてくる人なら、勝率は上がり、コールが良くなります。',
    );
  }

  /// 相手が賭けた（レイズした）ストリートでは、ペア以上かドローがあった
  /// という前提に合うか。[upTo] のストリートまでを見る。
  static bool _survivesVillainBets(
    HandReviewInput input,
    List<PlayingCard> combo,
    Street upTo,
  ) {
    for (final street in Street.values) {
      if (street == Street.preflop || street.index > upTo.index) continue;
      final actions = switch (street) {
        Street.flop => input.flop.actions,
        Street.turn => input.turn.actions,
        Street.river => input.river.actions,
        Street.preflop => const <HandAction>[],
      };
      final villainBet = actions.any((a) => !a.isHero && a.action.isAggressive);
      if (!villainBet) continue;
      final board = [
        for (final s in Street.values)
          if (s.index <= street.index) ...input.boardOf(s),
      ];
      if (!_hasPairOrDraw(combo, board)) return false;
    }
    return true;
  }

  static bool _hasPairOrDraw(List<PlayingCard> hole, List<PlayingCard> board) {
    final boardRanks = {for (final card in board) card.rank};
    if (hole[0].rank == hole[1].rank) return true;
    if (hole.any((card) => boardRanks.contains(card.rank))) return true;
    final holeIdx = hole.map(FastHandEvaluator.indexOf).toList();
    final boardIdx = board.map(FastHandEvaluator.indexOf).toList();
    if (FastHandEvaluator.categoryOf(
          FastHandEvaluator.score([...holeIdx, ...boardIdx]),
        ) >=
        4) {
      return true;
    }
    if (board.length >= 5) return false;
    final used = {...holeIdx, ...boardIdx};
    final buffer = [...holeIdx, ...boardIdx, 0];
    var improving = 0;
    for (var card = 0; card < 52; card++) {
      if (used.contains(card)) continue;
      buffer[buffer.length - 1] = card;
      if (FastHandEvaluator.categoryOf(FastHandEvaluator.score(buffer)) >= 4) {
        improving++;
      }
    }
    return improving >= 4;
  }

  static List<List<PlayingCard>> _combosOf(StartingHand hand) {
    final suits = CardSuit.values;
    return switch (hand.shape) {
      HandShape.pair => [
        for (var i = 0; i < 4; i++)
          for (var j = i + 1; j < 4; j++)
            [
              PlayingCard(hand.high, suits[i]),
              PlayingCard(hand.high, suits[j]),
            ],
      ],
      HandShape.suited => [
        for (final suit in suits)
          [PlayingCard(hand.high, suit), PlayingCard(hand.low, suit)],
      ],
      HandShape.offsuit => [
        for (final a in suits)
          for (final b in suits)
            if (a != b) [PlayingCard(hand.high, a), PlayingCard(hand.low, b)],
      ],
    };
  }

  static String _pct(double value) => '${(value * 100).round()}%';

  static String _bb(double value) => formatBb(value);
}
