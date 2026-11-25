import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/application/practice_providers.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grade.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_reason.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_record.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/features/practice_table/domain/tendency/practice_tendency.dart';
import 'package:ai_poker_coach/features/practice_table/infrastructure/local_practice_log_repository.dart';
import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart'
    show keyValueStoreProvider;
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AA でオープン → AI（[villain]）がコール → フロップ [flop]。
PracticeHandEngine _toFlop(List<String> villain, List<String> flop) {
  final engine = PracticeHandEngine(
    deck: PracticeDeck.ordered(
      PlayingCard.parseAll(['Ah', 'As', ...villain, ...flop, '2s', '3s']),
    ),
  );
  engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
  engine.apply(Actor.villain, PokerActionType.call);
  return engine;
}

PracticeHandLog _log(int i, List<(DecisionKind, PracticeVerdict)> decisions) =>
    PracticeHandLog(
      recordId: 'r$i',
      createdAt: DateTime(2026, 11, 1).add(Duration(minutes: i)),
      opponentStyle: PracticeOpponentStyle.standard,
      decisions: [
        for (final (kind, verdict) in decisions)
          LoggedDecision(kind: kind, street: Street.flop, verdict: verdict),
      ],
    );

void main() {
  group('相手の型', () {
    test('ブラフ多め: A の無いペア無しの手で、自分から小さく賭ける', () {
      final engine = _toFlop(['Kc', 'Qd'], ['7h', '4c', '2d']);
      const standard = SimplePracticeOpponent();
      const bluffer = SimplePracticeOpponent(
        style: PracticeOpponentStyle.bluffer,
      );
      expect(standard.decide(engine.state).action, PokerActionType.check);
      expect(bluffer.decide(engine.state).action, PokerActionType.bet);
    });

    test('バリュー多め: ペアで大きく（ポットの 66% 近く）賭ける', () {
      final engine = _toFlop(['7c', '6d'], ['7h', '4c', '2d']);
      const standard = SimplePracticeOpponent();
      const value = SimplePracticeOpponent(
        style: PracticeOpponentStyle.valueHeavy,
      );
      final small = standard.decide(engine.state).sizeBb!;
      final big = value.decide(engine.state).sizeBb!;
      expect(big, greaterThan(small));
    });

    test('受けすぎ: 賭けられると A ハイでも受ける', () {
      final engine = _toFlop(['Ac', 'Qd'], ['7h', '4c', '2d']);
      engine.apply(Actor.villain, PokerActionType.check);
      engine.apply(Actor.hero, PokerActionType.bet, sizeBb: 3.75);
      const standard = SimplePracticeOpponent();
      const station = SimplePracticeOpponent(
        style: PracticeOpponentStyle.callingStation,
      );
      expect(standard.decide(engine.state).action, PokerActionType.fold);
      expect(station.decide(engine.state).action, PokerActionType.call);
    });

    test('型ごとの相手でも採点できる（相手の範囲を同じ打ち方で再現する）', () {
      final engine = _toFlop(['Kc', 'Qd'], ['7h', '4c', '2d']);
      const bluffer = SimplePracticeOpponent(
        style: PracticeOpponentStyle.bluffer,
      );
      final decision = bluffer.decide(engine.state);
      engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
      const grader = PracticeDecisionGrader(opponent: bluffer);
      final grade = grader.grade(engine.events)!;
      expect(grade.facingBet, isTrue);
      // ブラフ多めの相手のベットに AA で降りるのは損（×）。コールは降りるより得。
      expect(
        grade.gradeOf(PokerActionType.fold, null)!.verdict,
        PracticeVerdict.bad,
      );
      expect(grade.gradeOf(PokerActionType.call, null)!.evBb, greaterThan(0));
    });

    test('記録に相手の型が残り、読み戻せる', () {
      final engine = _toFlop(['Kc', 'Qd'], ['7h', '4c', '2d']);
      final record = PracticeHandRecord(
        id: 'x',
        createdAt: DateTime(2026, 11, 25),
        events: engine.events,
        endedByFold: false,
        winner: null,
        finalPotBb: 5.5,
        opponentStyle: PracticeOpponentStyle.valueHeavy,
      );
      expect(
        PracticeHandRecord.fromJson(record.toJson()).opponentStyle,
        PracticeOpponentStyle.valueHeavy,
      );
    });
  });

  group('傾向の分析', () {
    test('× のコールが多いと「受けすぎ」で、バリュー多めの相手を勧める', () {
      final logs = [
        for (var i = 0; i < 4; i++)
          _log(i, [
            (DecisionKind.open, PracticeVerdict.good),
            (
              DecisionKind.call,
              i.isEven ? PracticeVerdict.bad : PracticeVerdict.good,
            ),
          ]),
      ];
      final tendency = PracticeTendency.analyze(logs);
      expect(tendency.handCount, 4);
      expect(tendency.byKind[DecisionKind.call]!.bad, 2);
      expect(tendency.leaks, [PracticeLeak.overCalling]);
      expect(tendency.recommendedStyle, PracticeOpponentStyle.valueHeavy);
    });

    test('× が少なければ傾向とみなさず、ふつうの相手のまま', () {
      final tendency = PracticeTendency.analyze([
        _log(0, [(DecisionKind.fold, PracticeVerdict.bad)]),
        for (var i = 1; i < 6; i++)
          _log(i, [(DecisionKind.fold, PracticeVerdict.good)]),
      ]);
      expect(tendency.leaks, isEmpty);
      expect(tendency.recommendedStyle, PracticeOpponentStyle.standard);
    });

    test('突く相手の無い傾向（オープンの判断）だけなら、ふつうの相手', () {
      final tendency = PracticeTendency.analyze([
        for (var i = 0; i < 3; i++)
          _log(i, [(DecisionKind.open, PracticeVerdict.bad)]),
      ]);
      expect(tendency.leaks, [PracticeLeak.openRange]);
      expect(tendency.recommendedStyle, PracticeOpponentStyle.standard);
    });

    test('記録は JSON で保存・読み戻しできる（理由の判定も）', () async {
      final repo = LocalPracticeLogRepository(InMemoryKeyValueStore());
      await repo.save(
        PracticeHandLog(
          recordId: 'a',
          createdAt: DateTime(2026, 11, 25),
          opponentStyle: PracticeOpponentStyle.bluffer,
          decisions: const [
            LoggedDecision(
              kind: DecisionKind.call,
              street: Street.turn,
              verdict: PracticeVerdict.close,
              lossBb: 0.5,
              reason: DecisionReason.potOdds,
              reasonVerdict: ReasonVerdict.wrong,
            ),
          ],
        ),
      );
      final logs = await repo.all();
      final decision = logs.single.decisions.single;
      expect(logs.single.opponentStyle, PracticeOpponentStyle.bluffer);
      expect(decision.kind, DecisionKind.call);
      expect(decision.reason, DecisionReason.potOdds);
      expect(decision.reasonVerdict, ReasonVerdict.wrong);
      expect(
        PracticeTendency.analyze(logs).reasonStats[DecisionReason.potOdds],
        (0, 1),
      );
    });
  });

  test('育つ相手をオンにすると、次のハンドから多いミスを突く型になる', () async {
    final store = InMemoryKeyValueStore();
    final repo = LocalPracticeLogRepository(store);
    for (var i = 0; i < 3; i++) {
      await repo.save(_log(i, [(DecisionKind.bet, PracticeVerdict.bad)]));
    }
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(practiceTableProvider.notifier);
    await container.read(practiceTendencyProvider.future);

    controller.startNewHand();
    expect(
      container.read(practiceTableProvider)!.opponentStyle,
      PracticeOpponentStyle.standard,
    );

    controller.setAdaptiveOpponent(true);
    controller.startNewHand();
    final snapshot = container.read(practiceTableProvider)!;
    expect(snapshot.opponentStyle, PracticeOpponentStyle.callingStation);
    expect(snapshot.targetedLeak, PracticeLeak.overBetting);
  });
}
