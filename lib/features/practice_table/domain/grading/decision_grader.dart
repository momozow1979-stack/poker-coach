import 'dart:math';

import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/starting_hand.dart';
import '../../../../shared/models/street.dart';
import '../../../hand_review/domain/hand_flow.dart' show Actor;
import '../../../hand_review/domain/hand_read.dart';
import '../../../range_chart/domain/range_action.dart';
import '../../../range_chart/domain/range_repository.dart';
import '../../../range_chart/domain/range_spot.dart';
import '../../../range_chart/infrastructure/mock_range_repository.dart';
import '../practice_event.dart';
import '../practice_hand_state.dart';
import '../practice_opponent.dart';
import 'combo_equity.dart';
import 'decision_grade.dart';
import 'villain_range.dart';

/// ヒーローの 1 回の判断を、押せるボタンすべてについて採点する。
///
/// - プリフロップで最初にオープンするかどうか: アプリ同梱のレンジ表
///   （学習用の目安）の答えをそのまま使う。
/// - それ以外: このAI（[opponent]、決まった打ち方の相手）に対して、各選択肢
///   の損得を計算する。相手の手札は「ここまでの行動と矛盾しない手札すべて、
///   同じ確率」（[VillainRange]）とし、実際の手札は使わない。
///
/// **計算の簡略化（画面にも必ず書く）**: 今のストリートの賭けのやり取り
/// （ヒーローの行動 → AI の応答 → AI がレイズしたらヒーローのコール/
/// フォールド）までは正確に追う。そこで決着しなければ、残りのボードは
/// 「これ以上賭けずに最後まで見る」ものとして勝率で分ける。次のストリート
/// 以降の賭けは含めない。
class PracticeDecisionGrader {
  const PracticeDecisionGrader({
    required this.opponent,
    this.ranges = const MockRangeRepository(),
  });

  final PracticeOpponent opponent;
  final RangeRepository ranges;

  /// 一番良い選択肢との差がポットのこの割合以下なら ○。
  static const double goodLossRatio = 0.02;

  /// ここまでなら △（僅差・条件次第）。超えたら ×。
  /// 例: ポット 7BB で 1.75BB のコールを迫られ、損が 0.85BB（コール額の
  /// 半分）になる場面は、ポットの約 12% の損なので × になる。
  static const double closeLossRatio = 0.08;

  /// ポットが小さいときに、端数の差で ○ を外さないための下限（BB）。
  static const double minGoodLossBb = 0.05;

  /// [events] はヒーローが判断する直前まで（先頭は [HandDealt]）。
  /// ヒーローの番でない、または相手の行動と矛盾しない手札が 1 つも無い
  /// （= 記録と違う打ち方の相手で採点しようとした）場合は null。
  PracticeDecisionGrade? grade(List<PracticeEvent> events) {
    final state = PracticeHandState.replay(events);
    final choices = state.choices;
    if (!state.isHeroTurn || choices == null) return null;

    final options = _optionsFor(choices);
    if (isOpeningDecision(state)) {
      final byTable = _gradeByRangeTable(state, options);
      if (byTable != null) return byTable;
    }
    return _gradeVersusOpponent(events, state, options);
  }

  static List<PracticeOption> _optionsFor(PracticeActionChoices choices) => [
    for (final action in choices.choices)
      if (action == PokerActionType.bet || action == PokerActionType.raise)
        for (final size in choices.presetSizesBb)
          PracticeOption(action, sizeBb: size)
      else
        PracticeOption(action),
  ];

  /// プリフロップで、ヒーローがまだ一度も行動していない（= オープンするか
  /// 決める）場面か。
  static bool isOpeningDecision(PracticeHandState state) =>
      state.street == Street.preflop &&
      !state.actions.any((action) => action.actor == Actor.hero);

  PracticeDecisionGrade? _gradeByRangeTable(
    PracticeHandState state,
    List<PracticeOption> options,
  ) {
    final chart = ranges.chartFor(
      state.tableType,
      state.heroPosition,
      situation: RangeSituation.openRaise,
    );
    if (chart == null) return null;
    final hand = StartingHand.fromCards(state.heroCards[0], state.heroCards[1]);
    final tableAction = chart.entryFor(hand).action;
    final plays = tableAction == RangeAction.raise;
    final borderline = tableAction == RangeAction.mixed;

    PracticeVerdict verdictFor(PokerActionType action) => switch (action) {
      PokerActionType.raise || PokerActionType.bet =>
        plays || borderline ? PracticeVerdict.good : PracticeVerdict.bad,
      PokerActionType.fold =>
        plays ? PracticeVerdict.bad : PracticeVerdict.good,
      // レンジ表は「オープンするか降りるか」の二択。コールだけ（リンプ）と
      // 100BB のオールインは表の想定外なので、断定せず △/× にとどめる。
      PokerActionType.call || PokerActionType.check => PracticeVerdict.close,
      PokerActionType.allIn =>
        plays || borderline ? PracticeVerdict.close : PracticeVerdict.bad,
    };

    return PracticeDecisionGrade(
      basis: GradingBasis.rangeTable,
      street: state.street,
      potBb: state.pot,
      toCallBb: state.heroToCallBb,
      heroHandCode: hand.code,
      rangeAction: tableAction,
      options: [
        for (final option in options)
          PracticeOptionGrade(
            option: option,
            verdict: verdictFor(option.action),
          ),
      ],
    );
  }

  PracticeDecisionGrade? _gradeVersusOpponent(
    List<PracticeEvent> events,
    PracticeHandState state,
    List<PracticeOption> options,
  ) {
    final combos = VillainRange.consistentCombos(
      events: events,
      opponent: opponent,
    );
    if (combos.isEmpty) return null;
    final equities = ComboEquities.compute(
      hero: state.heroCards,
      board: state.board,
      combos: combos,
    );

    final outcomes = [
      for (final option in options)
        _simulate(option, events, state, combos, equities),
    ];
    final bestEv = outcomes.map((outcome) => outcome.ev).reduce(max);
    final goodLoss = max(state.pot * goodLossRatio, minGoodLossBb);
    final closeLoss = state.pot * closeLossRatio;

    // あと 1 枚で完成するドローだけ（バックドア = あと 2 枚は、後で取れる
    // 分を当てにするには遠すぎるので含めない）。
    final draws = state.board.length >= 3 && state.board.length <= 4
        ? [
            for (final draw in HandRead.of(state.heroCards, state.board).draws)
              if (!draw.contains('バックドア')) draw,
          ]
        : const <String>[];

    final grades = <PracticeOptionGrade>[];
    for (var i = 0; i < options.length; i++) {
      final outcome = outcomes[i];
      final loss = bestEv - outcome.ev;
      var verdict = loss <= goodLoss
          ? PracticeVerdict.good
          : (loss <= closeLoss ? PracticeVerdict.close : PracticeVerdict.bad);
      // 計算は今のストリートで止めているので、ドローを追いかけるコールの
      // 「完成したら後で追加で取れる分（インプライドオッズ）」が入っていない。
      // その分を無視して × と断定しないよう、△ にとどめる。
      var softened = false;
      if (verdict == PracticeVerdict.bad &&
          options[i].action == PokerActionType.call &&
          (state.street == Street.flop || state.street == Street.turn) &&
          draws.isNotEmpty) {
        verdict = PracticeVerdict.close;
        softened = true;
      }
      grades.add(
        PracticeOptionGrade(
          option: options[i],
          verdict: verdict,
          evBb: outcome.ev,
          lossBb: loss,
          heroAddBb: outcome.heroAdd,
          foldRate: outcome.foldRate,
          raiseRate: outcome.raiseRate,
          equityWhenCalled: outcome.equityWhenCalled,
          breakEvenFoldRate: options[i].action.isAggressive
              ? outcome.heroAdd / (state.pot + outcome.heroAdd)
              : null,
          impliedOddsSoftened: softened,
        ),
      );
    }

    final toCall = state.heroToCallBb;
    return PracticeDecisionGrade(
      basis: GradingBasis.versusOpponent,
      street: state.street,
      potBb: state.pot,
      toCallBb: toCall > 0.0001 ? toCall : 0,
      options: grades,
      rangeComboCount: combos.length,
      heroEquity: equities.mean,
      equityIsExact: equities.isExact,
      equityMargin: equities.margin,
      equitySamplesPerCombo: equities.samplesPerCombo,
      requiredEquity: toCall > 0.0001 ? toCall / (state.pot + toCall) : null,
      heroDraws: draws,
    );
  }

  /// [option] を選んだときの損得の見込みを、相手の手札の候補すべてで平均する。
  _Outcome _simulate(
    PracticeOption option,
    List<PracticeEvent> events,
    PracticeHandState before,
    List<List<PlayingCard>> combos,
    ComboEquities equities,
  ) {
    if (option.action == PokerActionType.fold) {
      return const _Outcome(ev: 0, heroAdd: 0);
    }
    final heroEvent = ActionOccurred(
      street: before.street,
      actor: Actor.hero,
      action: option.action,
      sizeBb: option.sizeBb,
    );

    var total = 0.0;
    var heroAdd = 0.0;
    final folded = <int>[];
    final called = <int>[];
    // 相手がレイズし返した（または、ヒーローのチェックの後に賭けた）手札。
    // ヒーローは相手の手札を知らないので、コールするか降りるかは
    // 「その賭け方をしてくる手札全体」に対する勝率で 1 つに決める。
    final raisedBySize = <double, List<_Raised>>{};

    for (var i = 0; i < combos.length; i++) {
      final base = VillainRange.withVillainCards(events, combos[i]);
      final afterHero = PracticeHandState.replay([...base, heroEvent]);
      heroAdd = before.heroStack - afterHero.heroStack;
      if (afterHero.actorToAct != Actor.villain) {
        // チェックで回った／コールで揃った: ここから先は勝率で分ける。
        total += equities.values[i] * afterHero.pot - heroAdd;
        continue;
      }
      final decision = opponent.decide(afterHero);
      final afterVillain = PracticeHandState.replay([
        ...base,
        heroEvent,
        ActionOccurred(
          street: before.street,
          actor: Actor.villain,
          action: decision.action,
          sizeBb: decision.sizeBb,
        ),
      ]);
      if (afterVillain.isOver) {
        // 相手が降りた: ポットを丸ごと取る（自分の賭けも戻る）。
        total += afterHero.pot - heroAdd;
        folded.add(i);
      } else if (afterVillain.actorToAct == Actor.hero) {
        raisedBySize
            .putIfAbsent(decision.sizeBb ?? 0, () => [])
            .add(
              _Raised(
                index: i,
                potBb: afterVillain.pot,
                toCallBb: min(
                  afterVillain.heroToCallBb,
                  afterVillain.heroStack,
                ),
              ),
            );
      } else {
        total += equities.values[i] * afterVillain.pot - heroAdd;
        called.add(i);
      }
    }

    var raisedCount = 0;
    for (final group in raisedBySize.values) {
      raisedCount += group.length;
      final groupEquity = equities.meanOf(group.map((r) => r.index));
      final first = group.first;
      final callGain =
          groupEquity * (first.potBb + first.toCallBb) - first.toCallBb;
      for (final raised in group) {
        total += callGain > 0
            ? equities.values[raised.index] * (raised.potBb + raised.toCallBb) -
                  raised.toCallBb -
                  heroAdd
            : -heroAdd;
      }
    }

    final n = combos.length;
    final aggressive = option.action.isAggressive;
    return _Outcome(
      ev: total / n,
      heroAdd: heroAdd,
      foldRate: aggressive ? folded.length / n : null,
      raiseRate: aggressive ? raisedCount / n : null,
      equityWhenCalled: aggressive && called.isNotEmpty
          ? equities.meanOf(called)
          : null,
    );
  }
}

class _Outcome {
  const _Outcome({
    required this.ev,
    required this.heroAdd,
    this.foldRate,
    this.raiseRate,
    this.equityWhenCalled,
  });

  final double ev;
  final double heroAdd;
  final double? foldRate;
  final double? raiseRate;
  final double? equityWhenCalled;
}

class _Raised {
  const _Raised({
    required this.index,
    required this.potBb,
    required this.toCallBb,
  });

  final int index;
  final double potBb;
  final double toCallBb;
}
