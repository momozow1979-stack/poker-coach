import 'dart:math';

import 'package:ai_poker_coach/features/drills/application/drill_providers.dart';
import 'package:ai_poker_coach/features/drills/domain/bluff_drill_opponent.dart';
import 'package:ai_poker_coach/features/drills/domain/bluff_spot.dart';
import 'package:ai_poker_coach/features/drills/presentation/bluff_drill_page.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _opponent = BluffDrillOpponent();

BluffDrillHandKind _kind(List<String> hole, List<String> board) =>
    BluffDrillOpponent.classify(
      PlayingCard.parseAll(hole),
      PlayingCard.parseAll(board),
    ).kind;

/// ヒーロー（BTN）がオープン、AI がコールしてフロップへ。AI の手札は [villain]。
PracticeHandEngine _toFlop(List<String> villain, List<String> flop) {
  final engine = PracticeHandEngine(
    deck: PracticeDeck.ordered(
      PlayingCard.parseAll(['2c', '3d', ...villain, ...flop, '4s', '5s']),
    ),
  );
  engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
  engine.apply(Actor.villain, PokerActionType.call);
  return engine;
}

void main() {
  group('相手の手の強さの分類', () {
    test('トップペア・弱いペア・ドロー・A ハイ・何も無し', () {
      expect(
        _kind(['Kh', 'Qd'], ['Ks', '7c', '2d']),
        BluffDrillHandKind.topPair,
      );
      expect(
        _kind(['7h', '6d'], ['Ks', '7c', '2d']),
        BluffDrillHandKind.weakPair,
      );
      expect(_kind(['Ah', '5h'], ['Kh', '7h', '2d']), BluffDrillHandKind.draw);
      expect(
        _kind(['Ad', '4c'], ['Kh', '7h', '2d', '9s', 'Js']),
        BluffDrillHandKind.aceHigh,
      );
      expect(
        _kind(['8d', '4c'], ['Kh', 'Qh', '2d']),
        BluffDrillHandKind.nothing,
      );
    });

    test('ボードだけのペアは自分の役として数えない／セットは強い', () {
      expect(
        _kind(['9d', '4c'], ['Kh', 'Kc', '2d']),
        BluffDrillHandKind.nothing,
      );
      expect(
        _kind(['7d', '7s'], ['Ks', '7c', '2d']),
        BluffDrillHandKind.twoPairOrBetter,
      );
    });
  });

  group('相手の打ち方', () {
    test('フロップ以降、自分からは必ずチェックする', () {
      final engine = _toFlop(['Kh', 'Kd'], ['Ks', '7c', '2d']);
      expect(_opponent.decide(engine.state).action, PokerActionType.check);
    });

    test('弱いペアはポットの半分までは受け、それより大きいと降りる', () {
      PokerActionType responseTo(double bet) {
        final engine = _toFlop(['7h', '6d'], ['Ks', '7c', '2d']);
        engine.apply(Actor.villain, PokerActionType.check);
        engine.apply(Actor.hero, PokerActionType.bet, sizeBb: bet);
        return _opponent.decide(engine.state).action;
      }

      // ポットは 5.5BB。
      expect(responseTo(1.75), PokerActionType.call); // 32%
      expect(responseTo(2.75), PokerActionType.call); // 50%
      expect(responseTo(5.5), PokerActionType.fold); // 100%
    });
  });

  test('出題は「相手がチェックしてきて、勝率 50% 未満」の場面で、選択肢が揃っている', () async {
    final generator = BluffSpotGenerator(
      opponent: _opponent,
      grader: const PracticeDecisionGrader(opponent: _opponent),
      random: Random(4),
    );
    final streets = <String>{};
    for (var i = 0; i < 8; i++) {
      final spot = await generator.next();
      final hand = spot.hand;
      expect(hand.isHeroTurn, isTrue);
      expect(hand.choices!.facingBet, isFalse);
      expect(spot.grade.heroEquity, lessThan(0.5));
      expect(spot.bets, hasLength(3));
      expect(spot.check.option.action, PokerActionType.check);
      // 一番得な選択は、選択肢の中で損が 0。
      expect(spot.best.lossBb, closeTo(0, 1e-9));
      streets.add(hand.street.name);
    }
    expect(streets.length, greaterThan(1));
  });

  testWidgets('ブラフするか → 額 の順に選ぶと、比較表と解説が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [drillRandomProvider.overrideWithValue(Random(9))],
        child: const MaterialApp(home: BluffDrillPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('ブラフしますか？'), findsOneWidget);

    await tester.tap(find.text('ブラフする'));
    await tester.pump();
    expect(find.text('いくら賭けますか？'), findsOneWidget);
    await tester.tap(find.textContaining('ポットの').first);
    await tester.pump();
    final comparison = find.text('選択肢ごとの比較（この相手に対して）');
    for (var i = 0; i < 20 && comparison.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
    }
    expect(comparison, findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    expect(find.text('一番得'), findsOneWidget);
  });
}
