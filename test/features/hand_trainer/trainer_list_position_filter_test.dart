import 'package:ai_poker_coach/features/hand_trainer/presentation/trainer_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: TrainerListPage())),
  );
  await tester.pumpAndSettle();
}

/// 画面外にある要素が見つかるまでリストを下にスクロールする。
Future<void> _scrollDownTo(WidgetTester tester, Finder finder) async {
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

/// リストを先頭まで戻す（絞り込みチップは先頭付近にあるため）。
Future<void> _scrollToTop(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 260));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('ポジションで絞り込むと、そのポジションのハンドだけが残る', (tester) async {
    await _pump(tester);

    // 絞り込み前は BTN・BB どちらのハンドも一覧にある。
    await _scrollDownTo(tester, find.text('BTNのAK、ボードが全部ハート'));
    expect(find.text('BTNのAK、ボードが全部ハート'), findsOneWidget);
    await _scrollDownTo(tester, find.text('BBの3ベット、8が2枚のボード'));
    expect(find.text('BBの3ベット、8が2枚のボード'), findsOneWidget);

    await _scrollToTop(tester);
    await tester.tap(find.text('BTN'));
    await tester.pumpAndSettle();

    await _scrollDownTo(tester, find.text('BTNのAK、ボードが全部ハート'));
    expect(find.text('BTNのAK、ボードが全部ハート'), findsOneWidget);
    expect(find.text('BBの3ベット、8が2枚のボード'), findsNothing);

    // 「すべて」に戻すと両方また出る。
    await _scrollToTop(tester);
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();

    await _scrollDownTo(tester, find.text('BBの3ベット、8が2枚のボード'));
    expect(find.text('BBの3ベット、8が2枚のボード'), findsOneWidget);
  });
}
