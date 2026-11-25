import 'dart:math';

import 'package:ai_poker_coach/features/drills/application/drill_providers.dart';
import 'package:ai_poker_coach/features/drills/domain/preflop_drill.dart';
import 'package:ai_poker_coach/features/drills/presentation/preflop_drill_page.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_spot.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ranges = MockRangeRepository();

PreflopDrillQuestion _question(
  Position position,
  String hand, {
  RangeSituation situation = RangeSituation.openRaise,
}) {
  final chart = _ranges.chartFor(
    TableType.sixMax,
    position,
    situation: situation,
  )!;
  final parsed = StartingHand.parse(hand);
  return PreflopDrillQuestion(chart: chart, hand: parsed, cards: const []);
}

void main() {
  group('正解はレンジ表のとおり', () {
    test('BTN の AA はレイズ、72o はフォールド', () {
      expect(_question(Position.btn, 'AA').correctAnswers, {
        PreflopDrillAnswer.raise,
      });
      expect(_question(Position.btn, '72o').correctAnswers, {
        PreflopDrillAnswer.fold,
      });
    });

    test('境目の手（mixed）はどちらも正解', () {
      // BTN の K2s は境目（オープンしても降りてもよい）。
      final answers = _question(Position.btn, 'K2s').correctAnswers;
      expect(
        answers,
        containsAll([PreflopDrillAnswer.fold, PreflopDrillAnswer.raise]),
      );
    });

    test('相手のオープンに対しては「降りる・コール・3ベット」から選ぶ', () {
      final question = _question(
        Position.bb,
        'AA',
        situation: RangeSituation.vsOpen,
      );
      expect(question.choices, [
        PreflopDrillAnswer.fold,
        PreflopDrillAnswer.call,
        PreflopDrillAnswer.threeBet,
      ]);
      expect(question.correctAnswers, {PreflopDrillAnswer.threeBet});
    });
  });

  test('出題は 6MAX のオープンと vs オープンから、席の絞り込みも効く', () {
    final generator = PreflopDrillGenerator(ranges: _ranges, random: Random(1));
    final situations = {
      for (final chart in generator.charts) chart.spot.situation,
    };
    expect(situations, {RangeSituation.openRaise, RangeSituation.vsOpen});
    for (var i = 0; i < 30; i++) {
      final question = generator.next(onlyPosition: Position.co);
      expect(question.spot.heroPosition, Position.co);
      expect(question.cards, hasLength(2));
      expect(
        StartingHand.fromCards(question.cards[0], question.cards[1]),
        question.hand,
      );
    }
  });

  test('境目の手は、表で隣と答えが違うマスか mixed', () {
    final chart = _ranges.chartFor(TableType.sixMax, Position.btn)!;
    final boundary = PreflopDrillGenerator.boundaryHands(chart);
    expect(boundary.map((h) => h.code), contains('K2s'));
    expect(boundary.map((h) => h.code), isNot(contains('AA')));
    expect(boundary.map((h) => h.code), isNot(contains('72o')));
  });

  test('セッション: 連続正解・間違えた問題・最後は解説を見てから結果へ', () {
    final generator = PreflopDrillGenerator(ranges: _ranges, random: Random(3));
    final session = PreflopDrillSession(generator, length: 3);
    for (var i = 0; i < 3; i++) {
      final question = session.current;
      final wrong = question.choices.firstWhere(
        (c) => !question.correctAnswers.contains(c),
      );
      session.answer(i == 1 ? wrong : question.correctAnswers.first);
      if (i < 2) {
        expect(session.isLastAnswered, isFalse);
        session.next();
      }
    }
    expect(session.correct, 2);
    expect(session.bestStreak, 1);
    expect(session.mistakes, hasLength(1));
    expect(session.isLastAnswered, isTrue);
    expect(session.isFinished, isFalse); // 最後の解説を表示中
    session.next();
    expect(session.isFinished, isTrue);

    final retry = PreflopDrillSession(
      generator,
      retryQuestions: [for (final m in session.mistakes) m.question],
    );
    expect(retry.total, 1);
    expect(retry.current, same(session.mistakes.single.question));
  });

  testWidgets('答えるとすぐ ○× と理由、「次の問題」で進む', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [drillRandomProvider.overrideWithValue(Random(5))],
        child: const MaterialApp(home: PreflopDrillPage()),
      ),
    );
    await tester.pump();
    expect(find.text('1 / 20 問'), findsOneWidget);

    await tester.tap(find.text('フォールド'));
    await tester.pump();
    expect(find.textContaining('レンジ表の答え'), findsOneWidget);
    expect(find.text('こうなら答えが変わる'), findsOneWidget);
    expect(
      find.text('○').evaluate().length + find.text('×').evaluate().length,
      1,
    );

    await tester.ensureVisible(find.text('次の問題'));
    await tester.pump();
    await tester.tap(find.text('次の問題'));
    await tester.pump();
    expect(find.text('2 / 20 問'), findsOneWidget);
  });
}
