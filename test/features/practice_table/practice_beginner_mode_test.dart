import 'package:ai_poker_coach/features/practice_table/application/practice_providers.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_reason.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/presentation/practice_table_page.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// ヒーロー AA・AI 72o（AI はオープンに降りる手）。
PracticeDeck _deck() => PracticeDeck.ordered(
  PlayingCard.parseAll(['Ah', 'As', '7c', '2d', '3h', '4h', '5h', '9c', 'Tc']),
);

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [practiceDeckFactoryProvider.overrideWithValue(_deck)],
      child: const MaterialApp(home: PracticeTablePage()),
    ),
  );
  // 最初のハンドを配る・カードがめくれるのを待つ。
  await tester.pump(const Duration(seconds: 1));
}

/// 3 段階（アクション → 額 → 理由）でオープンする。
Future<void> _open(WidgetTester tester, {String? reason}) async {
  await tester.tap(find.text('レイズ'));
  await tester.pump();
  expect(find.text('レイズ額を選ぶ'), findsOneWidget);
  await tester.tap(find.text('2.5BB'));
  await tester.pump();
  expect(find.text('なぜ「レイズ 2.5BB」？'), findsOneWidget);
  await tester.tap(find.text(reason ?? DecisionReason.rangeOpen.label));
}

void main() {
  testWidgets('アクション → 額 → 理由 の順に選び、「戻る」で選び直せる', (tester) async {
    await _pumpPage(tester);

    // 1 段目は行動だけ（額ごとのボタンは並べない）。
    expect(find.text('レイズ'), findsOneWidget);
    expect(find.text('2.5BB'), findsNothing);

    await tester.tap(find.text('レイズ'));
    await tester.pump();
    expect(find.text('2.5BB'), findsOneWidget);
    await tester.tap(find.byTooltip('アクションを選び直す'));
    await tester.pump();
    expect(find.text('2.5BB'), findsNothing);
    expect(find.text('フォールド'), findsOneWidget);

    // フォールドは額が要らないので、すぐ理由を聞く。
    await tester.tap(find.text('フォールド'));
    await tester.pump();
    expect(find.text('なぜ「フォールド」？'), findsOneWidget);
    expect(find.text(DecisionReason.rangeFold.label), findsOneWidget);
    expect(find.text(DecisionReason.unsure.label), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('初心者モード: 選ぶとすぐ○△×と理由の判定が出て、やり直してから進められる', (tester) async {
    await _pumpPage(tester);
    expect(find.text('初心者モード'), findsOneWidget);

    // AA を「オープンしない手だから」降りる → アクションも理由も×。
    await tester.tap(find.text('フォールド'));
    await tester.pump();
    await tester.tap(find.text(DecisionReason.rangeFold.label));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('× 損をする選択です'), findsOneWidget);
    expect(find.text('レンジ表の答え: レイズしてオープン（2〜3BB）'), findsOneWidget);
    expect(find.text('理由が数字と合っていません'), findsOneWidget);
    expect(find.text('AA はレンジ表でオープンする手です。'), findsOneWidget);

    // やり直すと、同じ場面のボタンに戻る。
    await tester.tap(find.text('やり直す'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('× 損をする選択です'), findsNothing);
    expect(find.text('フォールド'), findsOneWidget);

    // 今度はオープン → ○、理由も○。
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('○ 良い選択です'), findsOneWidget);
    expect(find.text('あなたの選択: レイズ 2.5BB'), findsOneWidget);
    expect(find.text('理由も合っています'), findsOneWidget);

    // このまま進むと、AI（72o）が降りてハンドが終わり、総合評価が出る。
    await tester.tap(find.text('このまま進む'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('このハンドの評価'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('アクション 2/2点（○2・△1・×0）　理由 1/1点'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('通してプレイすると、終わった時点で総合評価が出て、1手ずつ振り返れる', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.textContaining('終わってから振り返ります'), findsOneWidget);

    // 「なんとなく」でも進められる（理由は 0 点）。
    await _open(tester, reason: DecisionReason.unsure.label);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('○ 良い選択です'), findsNothing);
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);

    // ハンドが終わったら、何もしなくても評価が出る。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('このハンドの評価'), findsOneWidget);
    expect(find.text('67'), findsOneWidget);
    expect(find.text('アクション 2/2点（○2・△1・×0）　理由 0/1点'), findsOneWidget);

    await tester.tap(find.text('1手ずつ振り返る'));
    await tester.pumpAndSettle();
    expect(find.text('ふりかえり'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));

    // 最初の判断の場面から始まり、判定と理由の判定が出ている。
    expect(find.text('あなた レイズ 2.5BB'), findsOneWidget);
    expect(find.text('○ 良い選択です'), findsOneWidget);
    expect(find.text('理由が言えるようになるともっと伸びます'), findsOneWidget);

    // 1 つ戻る（ヒーローの行動ではない場面）と、判定は消える。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pump();
    expect(find.text('○ 良い選択です'), findsNothing);

    // 「次の判断」で判断の場面へ戻れる。
    await tester.tap(find.text('次の判断'));
    await tester.pump();
    expect(find.text('○ 良い選択です'), findsOneWidget);
  });

  testWidgets('初心者モードを切ると、選んだアクションがそのまま確定する', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await _open(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('○ 良い選択です'), findsNothing);
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
