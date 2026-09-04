import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stores.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/json_learning_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/onboarding_test_helpers.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required KeyValueStore storage,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(storage)],
      child: const AiPokerCoachApp(),
    ),
  );
  await tester.pumpAndSettle();
}

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
  testWidgets('レビュータブは自分のハンドレビューの履歴一覧だけを見せる（トレーナー導線は無い）', (tester) async {
    final storage = await onboardingCompletedKeyValueStore();
    await _pumpApp(tester, storage: storage);

    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();

    expect(find.text('ハンドをレビューする'), findsWidgets);
    expect(find.text('意思決定トレーナー'), findsNothing);
    expect(find.text('ハンドトレーナー'), findsNothing);
  });

  testWidgets('履歴の1件をタップすると、その過去のレビュー結果を開ける', (tester) async {
    final storage = await onboardingCompletedKeyValueStore();
    await JsonLearningStore(storage).saveReview(
      StoredReview(
        review: fakeReview(
          id: 'review-history-1',
          createdAt: DateTime.now(),
          score: 88,
        ),
        synced: true,
      ),
    );

    await _pumpApp(tester, storage: storage);

    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();

    // 履歴カードが見える（提出前は「まだレビューがありません」ではない）。
    expect(find.text('まだレビューがありません'), findsNothing);
    expect(find.text('テスト用のレビュー'), findsOneWidget);

    await tester.tap(find.text('テスト用のレビュー'));
    await tester.pumpAndSettle();

    // 詳細画面: このセッションでは一度もレビューを「提出」していない
    // （`handReviewControllerProvider` は空のまま）のに、履歴から
    // 選んだ特定の過去レコードの内容が表示される。
    expect(find.text('レビュー結果'), findsOneWidget);
    expect(find.text('テスト用のレビュー'), findsOneWidget);
    await _scrollTo(tester, find.text('GTO視点'));
    expect(find.text('GTO視点'), findsOneWidget);
  });
}
