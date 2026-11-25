import 'dart:math';

import 'package:ai_poker_coach/features/drills/application/drill_providers.dart';
import 'package:ai_poker_coach/features/drills/domain/equity_quiz.dart';
import 'package:ai_poker_coach/features/drills/presentation/equity_quiz_page.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EquityQuizQuestion _question(
  List<String> hero,
  List<String> villain,
  List<String> board, {
  double equity = 0.5,
}) => EquityQuizQuestion(
  hero: PlayingCard.parseAll(hero),
  villain: PlayingCard.parseAll(villain),
  board: PlayingCard.parseAll(board),
  equity: equity,
  choices: const [20, 30, 40, 50],
);

void main() {
  test('ターンのナッツフラッシュドロー＋オーバーカード2枚 vs QQ: アウツ 15 枚', () {
    final question = _question(['Ah', 'Kh'], ['Qs', 'Qd'], [
      '2h',
      '7h',
      '9c',
      '3s',
    ]);
    final outs = question.outs!;
    expect(outs.heroIsBehind, isTrue);
    // ハート 9 枚 + ハート以外の A・K 3 枚ずつ。
    expect(outs.count, 15);
    expect(question.runoutCount, 44);
    expect(question.isFlop, isFalse);
  });

  test('出題の勝率は数え上げの正確な値で、アウツ÷残り枚数と一致する（ターン）', () {
    final generator = EquityQuizGenerator(random: Random(11));
    for (var i = 0; i < 40; i++) {
      final question = generator.next();
      expect(question.equity, inInclusiveRange(0.08, 0.92));
      expect(question.choices, contains(question.answer));
      expect(question.choices, hasLength(greaterThanOrEqualTo(3)));
      for (var j = 1; j < question.choices.length; j++) {
        expect(
          question.choices[j] - question.choices[j - 1],
          greaterThanOrEqualTo(10),
        );
      }
      final outs = question.outs;
      if (!question.isFlop && outs != null) {
        // ターンはあと 1 枚なので、逆転・引き分けの枚数から勝率がそのまま決まる。
        // （引き分けになるカードがあるとずれるので、その分を許す）
        final behindShare = outs.count / question.runoutCount;
        final heroShare = outs.heroIsBehind ? behindShare : 1 - behindShare;
        expect(question.equity, closeTo(heroShare, 4.5 / question.runoutCount));
      }
    }
  });

  test('一番近い 5% 刻みが正解', () {
    expect(EquityQuizQuestion.roundToFive(0.341), 35);
    expect(EquityQuizQuestion.roundToFive(0.324), 30);
  });

  testWidgets('勝率を選ぶと、正確な勝率とアウツの目安が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [drillRandomProvider.overrideWithValue(Random(2))],
        child: const MaterialApp(home: EquityQuizPage()),
      ),
    );
    await tester.pump();
    expect(find.text('1 / 10 問'), findsOneWidget);
    await tester.tap(find.textContaining('%').first);
    await tester.pump();
    expect(find.textContaining('あなたの勝率は'), findsOneWidget);
    expect(find.textContaining('通りを数えた値です'), findsOneWidget);
  });
}
