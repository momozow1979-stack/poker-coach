import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/hand_trainer/infrastructure/bundled_trainer_repository.dart';
import 'package:ai_poker_coach/features/hand_trainer/presentation/widgets/trainer_option_button.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: AiPokerCoachApp()));
  await tester.pumpAndSettle();
}

/// 画面外にある要素が見つかるまでリストをスクロールする。
///
/// `scrollUntilVisible` は `.first` 系の finder で落ちるため、手で drag する。
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  fail('要素が見つかりませんでした: $finder');
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _scrollTo(tester, find.text(text));
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// 表示中の設問で、[label] の評価を持つ選択肢を選ぶ。
Future<void> _chooseFirstOption(WidgetTester tester) async {
  await _scrollTo(tester, find.byType(TrainerOptionButton));
  final buttons = find.byType(TrainerOptionButton);
  // 最善の選択肢を選ぶ。どのシナリオでも必ず1つはある。
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final widget = tester.widget<TrainerOptionButton>(buttons.at(i));
    if (widget.option.verdict.isBest) {
      await tester.ensureVisible(buttons.at(i));
      await tester.pumpAndSettle();
      await tester.tap(buttons.at(i));
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('最善の選択肢が見つかりませんでした');
}

void main() {
  group('同梱シナリオの整合性', () {
    final scenarios = const BundledTrainerRepository().all();

    test('シナリオがある', () {
      expect(scenarios, isNotEmpty);
    });

    test('ID が重複していない', () {
      final ids = scenarios.map((scenario) => scenario.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('各設問に最善が1つだけあり、選択肢は重複しない', () {
      for (final scenario in scenarios) {
        for (final spot in scenario.spots) {
          final best = spot.options.where((o) => o.verdict.isBest);
          expect(
            best,
            hasLength(1),
            reason: '${scenario.id} ${spot.street.id}',
          );

          final labels = spot.options.map((o) => o.label).toList();
          expect(
            labels.toSet(),
            hasLength(labels.length),
            reason: '${scenario.id} ${spot.street.id}',
          );
          final ids = spot.options.map((o) => o.id).toList();
          expect(ids.toSet(), hasLength(ids.length));
        }
      }
    });

    test('すべての選択肢に「なぜ」と「何が変われば」が書かれている', () {
      for (final scenario in scenarios) {
        for (final spot in scenario.spots) {
          for (final option in spot.options) {
            expect(
              option.reason.trim().length,
              greaterThanOrEqualTo(25),
              reason: '${scenario.id} ${spot.street.id} ${option.label}',
            );
            expect(
              option.ifChanged.trim().length,
              greaterThanOrEqualTo(25),
              reason: '${scenario.id} ${spot.street.id} ${option.label}',
            );
          }
        }
      }
    });

    test('IP / OOP がフロップ以降の行動順で判定される', () {
      // プリフロップの順番で比べると BTN が BB より先に見えてしまう。
      expect(
        Position.btn.isInPositionAgainst(Position.bb, TableType.sixMax),
        isTrue,
      );
      expect(
        Position.bb.isInPositionAgainst(Position.btn, TableType.sixMax),
        isFalse,
      );
      expect(
        Position.sb.isInPositionAgainst(Position.bb, TableType.sixMax),
        isFalse,
      );
      expect(
        Position.co.isInPositionAgainst(Position.utg, TableType.nineMax),
        isTrue,
      );
    });

    test('カードが重複していない', () {
      for (final scenario in scenarios) {
        final cards = [...scenario.heroCards, ...scenario.fullBoard];
        expect(
          cards.map((card) => card.code).toSet(),
          hasLength(cards.length),
          reason: scenario.id,
        );
      }
    });

    test('ストリートの順番とボードの枚数が正しい', () {
      const expected = {'preflop': 0, 'flop': 3, 'turn': 1, 'river': 1};
      for (final scenario in scenarios) {
        for (final spot in scenario.spots) {
          expect(
            spot.newCards.length,
            expected[spot.street.id],
            reason: '${scenario.id} ${spot.street.id}',
          );
          expect(spot.potBb, greaterThan(0), reason: scenario.id);
          expect(spot.stackBb, greaterThan(0), reason: scenario.id);
        }
      }
    });

    test('GTO の頻度や EV の数値を書いていない', () {
      final frequency = RegExp(
        r'(GTO|ソルバー|solver)[^。]{0,40}?[0-9]+(\.[0-9]+)?\s*%',
      );
      final ev = RegExp(r'EV\s*[はが＝=:：]?\s*[+\-−]?[0-9]');
      for (final scenario in scenarios) {
        final texts = <String>[
          scenario.goal,
          scenario.takeaway,
          for (final spot in scenario.spots) ...[
            spot.question,
            spot.hint ?? '',
            spot.outcome ?? '',
            for (final option in spot.options) ...[
              option.reason,
              option.ifChanged,
            ],
          ],
        ];
        for (final text in texts) {
          expect(frequency.hasMatch(text), isFalse, reason: text);
          expect(ev.hasMatch(text), isFalse, reason: text);
        }
      }
    });

    test('必要勝率が計算どおりに出る', () {
      for (final scenario in scenarios) {
        for (final spot in scenario.spots) {
          if (spot.toCallBb <= 0) {
            expect(spot.requiredEquity, isNull);
            continue;
          }
          expect(
            spot.requiredEquity,
            closeTo(spot.toCallBb / (spot.potBb + spot.toCallBb), 1e-9),
          );
        }
      }
    });
  });

  testWidgets('トレーナーを最後まで進めると総括が出る', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();

    await _tapText(tester, 'ハンドを選ぶ');
    expect(find.text('意思決定トレーナー'), findsWidgets);

    // 一覧から1本目を開く。
    final scenario = const BundledTrainerRepository().all().first;
    await _tapText(tester, scenario.title);

    for (var i = 0; i < scenario.spotCount; i++) {
      await _chooseFirstOption(tester);
      expect(find.text('なぜそうなるか'), findsOneWidget);
      await _tapText(
        tester,
        i == scenario.spotCount - 1 ? '総括を見る' : '次のストリートへ',
      );
    }

    expect(find.text('ハンドおつかれさまでした'), findsOneWidget);
    await _scrollTo(tester, find.text('このハンドの学び'));
    expect(find.text('このハンドの学び'), findsOneWidget);
  });

  testWidgets('フォールドを選ぶとそこで終わる', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();
    await _tapText(tester, 'ハンドを選ぶ');

    final scenario = const BundledTrainerRepository().all().first;
    await _tapText(tester, scenario.title);

    await _tapText(tester, 'フォールド');
    await _tapText(tester, '総括を見る');

    expect(find.text('ハンドおつかれさまでした'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('フォールドを選んだので'));
  });
}
