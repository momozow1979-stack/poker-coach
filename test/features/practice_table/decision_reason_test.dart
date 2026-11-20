import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_reason.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/hand_reviewer.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_record.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter_test/flutter_test.dart';

const _opponent = SimplePracticeOpponent();
const _grader = PracticeDecisionGrader(opponent: _opponent);

/// AA でオープン → AI（KQ）がコール → フロップ 2c 7s 9d で AI がチェック。
PracticeHandEngine _flopAfterVillainCheck() {
  final engine = PracticeHandEngine(
    deck: PracticeDeck.ordered(
      PlayingCard.parseAll([
        'Ah',
        'As',
        'Ks',
        'Qd',
        '2c',
        '7s',
        '9d',
        '3c',
        '4s',
      ]),
    ),
  );
  engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
  while (engine.state.actorToAct == Actor.villain) {
    final decision = _opponent.decide(engine.state);
    engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
  }
  return engine;
}

void main() {
  group('理由の候補', () {
    test('プリフロップのオープン判断ではレンジ表の理由を聞き、リンプは聞かない', () {
      final engine = PracticeHandEngine(
        deck: PracticeDeck.ordered(
          PlayingCard.parseAll(['Ah', 'As', '7c', '2d', '3h', '4h', '5h']),
        ),
      );
      final hand = engine.state;
      expect(DecisionReason.optionsFor(hand, PokerActionType.raise), [
        DecisionReason.rangeOpen,
        DecisionReason.unsure,
      ]);
      expect(DecisionReason.optionsFor(hand, PokerActionType.fold), [
        DecisionReason.rangeFold,
        DecisionReason.unsure,
      ]);
      expect(DecisionReason.optionsFor(hand, PokerActionType.call), isEmpty);
    });

    test('フロップ・ターンだけドローの理由を出す', () {
      final flop = _flopAfterVillainCheck().state;
      expect(DecisionReason.optionsFor(flop, PokerActionType.bet), [
        DecisionReason.value,
        DecisionReason.bluff,
        DecisionReason.semiBluff,
        DecisionReason.unsure,
      ]);
      expect(DecisionReason.optionsFor(flop, PokerActionType.check), [
        DecisionReason.potControl,
        DecisionReason.giveUp,
        DecisionReason.trap,
        DecisionReason.unsure,
      ]);
    });
  });

  group('理由の判定（計算した数字だけで決める）', () {
    test('AA のチェック: このAIはベットに全部降りるので「罠」は○、「諦め」「ポット管理」は×', () {
      final events = _flopAfterVillainCheck().events;
      final grade = _grader.grade(events)!;
      final check = grade.gradeOf(PokerActionType.check, null)!;

      ReasonVerdict verdictOf(DecisionReason reason) =>
          ReasonGrader.grade(grade, check, reason).verdict;
      expect(verdictOf(DecisionReason.trap), ReasonVerdict.correct);
      expect(verdictOf(DecisionReason.giveUp), ReasonVerdict.wrong);
      expect(verdictOf(DecisionReason.potControl), ReasonVerdict.wrong);
      expect(verdictOf(DecisionReason.unsure), ReasonVerdict.unsure);
    });

    test('AA のベット: コールしてくる手が無いので「バリュー」は×、「ブラフ（降ろす）」は○', () {
      final events = _flopAfterVillainCheck().events;
      final grade = _grader.grade(events)!;
      final bet = grade.options.firstWhere(
        (option) => option.option.action == PokerActionType.bet,
      );

      final value = ReasonGrader.grade(grade, bet, DecisionReason.value);
      expect(value.verdict, ReasonVerdict.wrong);
      expect(value.explanation, contains('コールしてきません'));
      final bluff = ReasonGrader.grade(grade, bet, DecisionReason.bluff);
      expect(bluff.verdict, ReasonVerdict.correct);
      final semi = ReasonGrader.grade(grade, bet, DecisionReason.semiBluff);
      expect(semi.verdict, ReasonVerdict.wrong);
    });
  });

  test('理由は記録に保存され、振り返りの採点と総合点に入る', () async {
    final engine = _flopAfterVillainCheck();
    final checkIndex = engine.events.length;
    engine.apply(Actor.hero, PokerActionType.check);

    final record = PracticeHandRecord(
      id: 'r1',
      createdAt: DateTime(2026, 11, 20),
      events: engine.events,
      endedByFold: false,
      winner: null,
      finalPotBb: engine.state.pot,
      heroReasons: {checkIndex: DecisionReason.giveUp},
    );
    final restored = PracticeHandRecord.fromJson(record.toJson());
    expect(restored.heroReasons, {checkIndex: DecisionReason.giveUp});

    final review = await PracticeHandReviewer.review(
      restored.events,
      _grader,
      reasons: restored.heroReasons,
    );
    final flopDecision = review.atEvent(checkIndex)!;
    expect(flopDecision.reasonGrade!.verdict, ReasonVerdict.wrong);
    // オープンは理由なし（聞かなかった扱い）なので、理由の満点に入らない。
    expect(review.decisions.first.reasonGrade, isNull);
    final score = review.score;
    expect(score.reasonAnswered, 1);
    expect(score.reasonCorrect, 0);
    expect(score.actionMax, 4);
  });

  test('古い記録（理由なし）もそのまま読める', () {
    final engine = _flopAfterVillainCheck();
    final json = PracticeHandRecord(
      id: 'old',
      createdAt: DateTime(2026, 10, 1),
      events: engine.events,
      endedByFold: false,
      winner: null,
      finalPotBb: 5,
    ).toJson();
    expect(json.containsKey('hero_reasons'), isFalse);
    expect(PracticeHandRecord.fromJson(json).heroReasons, isEmpty);
  });
}
