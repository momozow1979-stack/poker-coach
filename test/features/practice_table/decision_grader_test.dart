import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grade.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/villain_range.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_action.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_notation.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:flutter_test/flutter_test.dart';

const _opponent = SimplePracticeOpponent();
const _grader = PracticeDecisionGrader(opponent: _opponent);

/// 先頭 2 枚がヒーロー、次の 2 枚が AI、残りがフロップ・ターン・リバー。
PracticeHandEngine _engine(List<String> cards) =>
    PracticeHandEngine(deck: PracticeDeck.ordered(PlayingCard.parseAll(cards)));

/// AI の番なら、AI 自身の決まりどおりに動かす（実戦と同じ記録にするため）。
void _driveVillain(PracticeHandEngine engine) {
  while (!engine.state.isOver && engine.state.actorToAct == Actor.villain) {
    final decision = _opponent.decide(engine.state);
    engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
  }
}

void _hero(PracticeHandEngine engine, PokerActionType action, {double? size}) {
  engine.apply(Actor.hero, action, sizeBb: size);
  _driveVillain(engine);
}

/// プリフロップでオープンし、以降はリバーまでチェックで回す。
PracticeHandEngine _checkedDownToRiver(List<String> cards) {
  final engine = _engine(cards);
  _hero(engine, PokerActionType.raise, size: 2.5);
  for (var street = 0; street < 2; street++) {
    _hero(engine, PokerActionType.check);
  }
  return engine;
}

void main() {
  group('プリフロップのオープン（レンジ表で採点）', () {
    test('レンジ表でオープンする手は、レイズが○・フォールドが×', () {
      final engine = _engine(['Ah', 'As', '7c', '2d']);
      final grade = _grader.grade(engine.events)!;

      expect(grade.basis, GradingBasis.rangeTable);
      expect(grade.heroHandCode, 'AA');
      expect(grade.rangeAction, RangeAction.raise);
      expect(
        grade.gradeOf(PokerActionType.raise, 2.5)!.verdict,
        PracticeVerdict.good,
      );
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.bad,
      );
      // 表に無い「コールだけ（リンプ）」は断定せず △。
      expect(
        grade.gradeOf(PokerActionType.call, null)!.verdict,
        PracticeVerdict.close,
      );
    });

    test('レンジ表で降りる手は、フォールドが○・レイズが×', () {
      final engine = _engine(['7h', '2c', 'Ac', 'Kd']);
      final grade = _grader.grade(engine.events)!;

      expect(grade.rangeAction, RangeAction.fold);
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.good,
      );
      expect(
        grade.gradeOf(PokerActionType.raise, 3.0)!.verdict,
        PracticeVerdict.bad,
      );
      expect(
        grade.gradeOf(PokerActionType.allIn, null)!.verdict,
        PracticeVerdict.bad,
      );
    });

    test('境界の手（mixed）は、レイズもフォールドも○', () {
      final engine = _engine(['Kh', '4h', 'Ac', 'Kd']);
      final grade = _grader.grade(engine.events)!;

      expect(grade.rangeAction, RangeAction.mixed);
      expect(
        grade.gradeOf(PokerActionType.raise, 2.2)!.verdict,
        PracticeVerdict.good,
      );
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.good,
      );
    });
  });

  group('相手の範囲（ここまでの行動と矛盾しない手札）', () {
    test('プリフロップでコールし、A-7-2 でチェックした相手は、ペアの無いコールレンジだけ', () {
      final engine = _engine(['Qh', 'Jh', 'Kc', 'Qd', 'Ad', '7s', '2h']);
      _hero(engine, PokerActionType.raise, size: 2.5);

      final combos = VillainRange.consistentCombos(
        events: engine.events,
        opponent: _opponent,
      );
      final callRange = RangeNotation.expand(
        '22+,A2s+,K8s+,Q9s+,J9s+,T8s+,97s+,86s+,75s+,64s+,54s,'
        'A9o+,KTo+,QTo+,JTo',
      );
      expect(combos, isNotEmpty);
      for (final combo in combos) {
        final code = StartingHand.fromCards(combo[0], combo[1]).code;
        expect(callRange, contains(code));
        // 見えているカード（ヒーローの手札とボード）は持っていない。
        expect(
          combo.map((c) => c.code),
          isNot(anyOf(contains('Qh'), contains('Jh'), contains('Ad'))),
        );
        // A・7・2 のどれかでペアになる手は、この AI ならベットしている。
        expect(
          combo.any((c) => {'A', '7', '2'}.contains(c.rank.symbol)),
          isFalse,
          reason: code,
        );
        // ポケットペアもベットしている。
        expect(combo[0].rank == combo[1].rank, isFalse, reason: code);
      }
    });
  });

  group('この AI に対する損得で採点', () {
    test('リバーで相手がチェック（ワンペアも無い）なら、どの額のベットでも全部降りる → ベット○・チェック×', () {
      final engine = _checkedDownToRiver([
        'Jh', 'Td', // hero（J ハイ）
        'Ks', 'Qd', // AI（K ハイ）
        '2c', '7s', '9d', '3c', '4s',
      ]);
      final grade = _grader.grade(engine.events)!;

      expect(grade.basis, GradingBasis.versusOpponent);
      expect(grade.equityIsExact, isTrue);
      expect(grade.heroEquity, lessThan(1));
      final bets = grade.options
          .where((g) => g.option.action == PokerActionType.bet)
          .toList();
      expect(bets, isNotEmpty);
      for (final bet in bets) {
        expect(bet.foldRate, 1.0);
        expect(bet.verdict, PracticeVerdict.good);
      }
      expect(
        grade.gradeOf(PokerActionType.check, null)!.verdict,
        PracticeVerdict.bad,
      );
    });

    test('相手の実際の手札は採点に使わない（同じ行動なら同じ採点）', () {
      List<double?> evs(List<String> villainCards) {
        final engine = _checkedDownToRiver([
          'Jh',
          'Td',
          ...villainCards,
          '2c',
          '7s',
          '9d',
          '3c',
          '4s',
        ]);
        return [for (final g in _grader.grade(engine.events)!.options) g.evBb];
      }

      // どちらも「コールしてチェックを続けた K ハイ」で、AI には区別がつかない。
      expect(evs(['Ks', 'Qd']), evs(['Kc', 'Jd']));
    });

    test('相手のベットに、勝率が必要勝率に届かない弱い手で直面 → フォールド○・コール×、ブラフのレイズは誰も降りないので×', () {
      final engine = _engine([
        '6h', '5h', // hero（6 ハイ、ドロー無し）
        'Ac', '9c', // AI（A のワンペアになる）
        'Ad', '7s', '2h', '3c', '4s',
      ]);
      _hero(engine, PokerActionType.raise, size: 2.5);
      // フロップで AI がワンペアで小さくベットし、ヒーローの番。
      expect(engine.state.isHeroTurn, isTrue);
      expect(engine.state.heroToCallBb, greaterThan(0));

      final grade = _grader.grade(engine.events)!;
      expect(grade.heroDraws, isEmpty);
      expect(grade.requiredEquity, isNotNull);
      expect(grade.heroEquity!, lessThan(grade.requiredEquity!));
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.good,
      );
      expect(
        grade.gradeOf(PokerActionType.call, null)!.verdict,
        PracticeVerdict.bad,
      );
      for (final raise in grade.options.where(
        (g) => g.option.action == PokerActionType.raise,
      )) {
        expect(raise.foldRate, 0);
        expect(raise.verdict, PracticeVerdict.bad);
      }
    });

    test('プリフロップの 3 ベットに直面したときは、勝率を推定（厳密ではない）と明示する', () {
      final engine = _engine(['Ah', 'Ks', 'Qc', 'Qd']);
      _hero(engine, PokerActionType.raise, size: 2.5);
      expect(engine.state.isHeroTurn, isTrue); // QQ は 3 ベットしてくる

      final grade = _grader.grade(engine.events)!;
      expect(grade.basis, GradingBasis.versusOpponent);
      expect(grade.equityIsExact, isFalse);
      expect(grade.equityMargin, greaterThan(0));
      expect(grade.equitySamplesPerCombo, greaterThan(0));
      // AK は QQ+・AK に対しても必要勝率を大きく上回るので、降りるのは損。
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.bad,
      );
    });
  });
}
