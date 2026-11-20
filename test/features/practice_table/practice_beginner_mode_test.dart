import 'package:ai_poker_coach/features/practice_table/application/practice_providers.dart';
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

void main() {
  testWidgets('初心者モード: 選ぶとすぐ○△×が出て、やり直してから進められる', (tester) async {
    await _pumpPage(tester);
    expect(find.text('初心者モード'), findsOneWidget);

    // AA を降りる → × と、レンジ表の答え。まだ確定していない。
    await tester.tap(find.text('フォールド'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('× 損をする選択です'), findsOneWidget);
    expect(find.text('レンジ表の答え: レイズしてオープン（2〜3BB）'), findsOneWidget);
    expect(find.text('やり直す'), findsOneWidget);

    // やり直すと、同じ場面のボタンに戻る。
    await tester.tap(find.text('やり直す'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('× 損をする選択です'), findsNothing);
    expect(find.text('フォールド'), findsOneWidget);

    // 今度はオープン → ○。
    await tester.tap(find.text('レイズ 2.5'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('○ 良い選択です'), findsOneWidget);
    expect(find.text('あなたの選択: レイズ 2.5BB'), findsOneWidget);

    // このまま進むと、AI（72o）が降りてハンドが終わる。
    await tester.tap(find.text('このまま進む'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('通してプレイしたあと「振り返る」で、判断ごとの○△×をプレイバックで見られる', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('終わってから振り返ります'), findsOneWidget);

    await tester.tap(find.text('レイズ 2.5'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);

    await tester.tap(find.text('振り返る'));
    await tester.pumpAndSettle();
    expect(find.text('ふりかえり'), findsOneWidget);
    // 採点が終わると、判断の一覧が出る。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('あなたの判断'), findsOneWidget);
    expect(find.text('○1'), findsOneWidget);

    // 判断のチップを押すと、その場面に移動して判定と理由が出る。
    await tester.tap(find.text('○ プリフロップ レイズ 2.5BB'));
    await tester.pump();
    expect(find.text('○ 良い選択です'), findsOneWidget);
    expect(find.text('あなた レイズ 2.5BB'), findsOneWidget);

    // 1 つ戻る（ヒーローの行動ではない場面）と、判定は消える。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pump();
    expect(find.text('○ 良い選択です'), findsNothing);
  });

  testWidgets('初心者モードを切ると、選んだアクションがそのまま確定する', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('レイズ 2.5'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('○ 良い選択です'), findsNothing);
    expect(find.textContaining('あなたの勝ち'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
