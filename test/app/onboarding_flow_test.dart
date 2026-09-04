import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/onboarding/infrastructure/onboarding_store.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester, KeyValueStore store) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const AiPokerCoachApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('初回起動はオンボーディングへリダイレクトされ、タブは出ない', (tester) async {
    await _pumpApp(tester, InMemoryKeyValueStore());

    expect(find.text('今のポーカーの実力を教えてください'), findsOneWidget);
    // タブバーはまだ出ない。
    expect(find.text('ホーム'), findsNothing);
  });

  testWidgets('3ステップを終えると保存され、ホームへ遷移する', (tester) async {
    final store = InMemoryKeyValueStore();
    await _pumpApp(tester, store);

    // ①レベル選択。
    await tester.tap(find.text('中級者'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    // ②学びたい分野（複数選択できる）。
    await tester.tap(find.text('フロップ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ターン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    // ③まとめ。
    expect(find.text('プランができました'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    // ホームへ遷移し、タブが出る。
    expect(find.text('今日の10問'), findsWidgets);
    for (final label in ['ホーム', '学習', 'レンジ', 'レビュー', 'マイページ']) {
      expect(find.text(label), findsWidgets, reason: label);
    }

    // 実際にローカルへ保存されている。
    final saved = await OnboardingStore(store).load();
    expect(saved, isNotNull);
    expect(saved!.pokerLevel.label, '中級者');
    expect(saved.focusCategories.map((c) => c.label), ['フロップ', 'ターン']);
  });

  testWidgets('完了済みなら再起動してもオンボーディングは出ない', (tester) async {
    final store = InMemoryKeyValueStore();
    await OnboardingStore(store).save(fakeOnboardingAnswers());

    await _pumpApp(tester, store);

    expect(find.text('今のポーカーの実力を教えてください'), findsNothing);
    expect(find.text('今日の10問'), findsWidgets);
  });
}
