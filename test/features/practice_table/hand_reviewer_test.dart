import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grade.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/hand_reviewer.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_event.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

const _opponent = SimplePracticeOpponent();
const _grader = PracticeDecisionGrader(opponent: _opponent);

PracticeHandEngine _engine(List<String> cards) =>
    PracticeHandEngine(deck: PracticeDeck.ordered(PlayingCard.parseAll(cards)));

void _hero(PracticeHandEngine engine, PokerActionType action, {double? size}) {
  engine.apply(Actor.hero, action, sizeBb: size);
  while (!engine.state.isOver && engine.state.actorToAct == Actor.villain) {
    final decision = _opponent.decide(engine.state);
    engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
  }
}

/// AA でオープン → AI（KQ）がコール → 全ストリート、AI のチェックに
/// ヒーローもチェックで回してショーダウン。
List<PracticeEvent> _checkedDownHand() {
  final engine = _engine([
    'Ah',
    'As',
    'Ks',
    'Qd',
    '2c',
    '7s',
    '9d',
    '3c',
    '4s',
  ]);
  _hero(engine, PokerActionType.raise, size: 2.5);
  _hero(engine, PokerActionType.check);
  _hero(engine, PokerActionType.check);
  _hero(engine, PokerActionType.check);
  expect(engine.state.isOver, isTrue);
  return engine.events;
}

void main() {
  test('ヒーローの判断をすべて、時系列順に、初心者モードと同じ採点で振り返る', () async {
    final events = _checkedDownHand();
    final review = await PracticeHandReviewer.review(events, _grader);

    expect(review.ungradedCount, 0);
    expect(review.decisions.map((d) => d.street), [
      Street.preflop,
      Street.flop,
      Street.turn,
      Street.river,
    ]);

    // プリフロップの AA オープンはレンジ表どおり○。
    final open = review.decisions.first;
    expect(open.grade.basis, GradingBasis.rangeTable);
    expect(open.chosen.verdict, PracticeVerdict.good);
    expect(open.explanation.title, '○ 良い選択です');

    // 各判断は、その判断の直前までのイベントで採点したものと同じ。
    for (final decision in review.decisions) {
      final direct = _grader.grade(events.sublist(0, decision.eventIndex))!;
      final event = events[decision.eventIndex] as ActionOccurred;
      expect(
        decision.chosen.verdict,
        direct.gradeOf(event.action, event.sizeBb)!.verdict,
      );
      expect(review.atEvent(decision.eventIndex), same(decision));
    }

    // ペアの無い相手のチェックに、AA でチェックを重ねたのは
    // 「ベットすれば全部降りる」このAIに対しては同じ得（勝率100%）なので○。
    final counts = {
      for (final v in PracticeVerdict.values) v: review.countOf(v),
    };
    expect(counts.values.reduce((a, b) => a + b), 4);
  });

  test('相手の実際の手札がどうであれ、ヒーローに見えた行動だけで採点する', () async {
    // 72o は今の AI ならオープンに降りる手だが、記録ではコールしている。
    // それでもヒーローに見えるのは「コールしてチェックした」ことだけで、
    // 今の AI がそう打つ手札は他にもあるので、フロップの判断も採点できる。
    final engine = _engine([
      'Ah',
      'As',
      '7c',
      '2d',
      'Kd',
      'Jc',
      '9h',
      '3s',
      '4d',
    ]);
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    engine.apply(Actor.villain, PokerActionType.call);
    engine.apply(Actor.villain, PokerActionType.check);
    engine.apply(Actor.hero, PokerActionType.check);

    final review = await PracticeHandReviewer.review(engine.events, _grader);
    expect(review.decisions.map((d) => d.street), [
      Street.preflop,
      Street.flop,
    ]);
    expect(review.ungradedCount, 0);
  });

  test('今の AI では起こりえない行動の記録は、間違った採点を出さず「採点できない」に数える', () async {
    // 今の AI の 3 ベットは常に 5BB。7BB の 3 ベットをする手札は 1 つも無い
    // （以前の打ち方の AI と対戦した記録などを想定）。
    final engine = _engine([
      'Ah',
      'Ks',
      'Qc',
      'Qd',
      '2c',
      '7s',
      '9d',
      '3c',
      '4s',
    ]);
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    engine.apply(Actor.villain, PokerActionType.raise, sizeBb: 7);
    engine.apply(Actor.hero, PokerActionType.call);

    final review = await PracticeHandReviewer.review(engine.events, _grader);
    // プリフロップのオープンはレンジ表で採点できる（相手の打ち方に依らない）。
    expect(review.decisions.single.street, Street.preflop);
    // 3 ベットへのコールは、相手の行動と矛盾しない手札が無いので採点しない。
    expect(review.ungradedCount, 1);
  });
}
