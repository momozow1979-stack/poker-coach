import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = await onboardingCompletedKeyValueStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const AiPokerCoachApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 画面外にある要素が見つかるまでリストをスクロールする。
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

void main() {
  testWidgets('学習タブのどこからでも、3つの入り口をすぐ切り替えられる', (tester) async {
    await _pumpApp(tester);

    // ホーム → 学習タブ（今日の10問）。
    await tester.tap(find.text('学習'));
    await tester.pumpAndSettle();
    expect(find.text('今日の10問'), findsWidgets);

    // 座学 → ハンドトレーナーへ切り替え。
    await tester.tap(find.text('ハンドトレーナー'));
    await tester.pumpAndSettle();
    expect(find.text('ハンドトレーナー'), findsWidgets);
    expect(find.text('ポジションで絞り込む'), findsOneWidget);

    // ハンドトレーナー → AI相手に練習へ切り替え。
    await tester.tap(find.text('AI相手に練習'));
    await tester.pumpAndSettle();
    expect(find.text('AI相手に練習'), findsWidgets);

    // AI相手に練習 → 座学へ戻る。
    await tester.tap(find.text('座学'));
    await tester.pumpAndSettle();
    expect(find.text('今日の10問'), findsWidgets);
  });

  testWidgets('ホームの看板カード「他のハンドを選ぶ」から一覧へ行ける', (tester) async {
    await _pumpApp(tester);

    await _scrollTo(tester, find.text('他のハンドを選ぶ'));
    await tester.tap(find.text('他のハンドを選ぶ'));
    await tester.pumpAndSettle();

    expect(find.text('ポジションで絞り込む'), findsOneWidget);
  });
}
