import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/auth/application/auth_providers.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stores.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/json_learning_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/onboarding_test_helpers.dart';

/// `Override` は flutter_riverpod から公開されていないので、
/// ProviderScope ごと受け取って型注釈を避ける。
Future<void> _pumpProfile(WidgetTester tester, ProviderScope scope) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(scope);
  await tester.pumpAndSettle();
  await tester.tap(find.text('マイページ'));
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
  testWidgets('履歴が空なら「まだデータがありません」と出る', (tester) async {
    await _pumpProfile(
      tester,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            await onboardingCompletedKeyValueStore(),
          ),
        ],
        child: const AiPokerCoachApp(),
      ),
    );

    expect(find.text('まだ学習データがありません'), findsOneWidget);
    // モックの偽データが混じっていないこと。
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('履歴があれば空状態は出ない', (tester) async {
    // 前回の起動で保存された状態を、保存領域に直接用意する。
    final storage = await onboardingCompletedKeyValueStore();
    await JsonLearningStore(storage).saveAttempt(
      StoredAttempt(
        attempt: fakeAttempt(quizId: 'preflop-001', answeredAt: DateTime.now()),
        synced: true,
      ),
    );

    await _pumpProfile(
      tester,
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(storage)],
        child: const AiPokerCoachApp(),
      ),
    );

    expect(find.text('まだ学習データがありません'), findsNothing);
  });

  testWidgets('アカウントカードに登録・ログインの導線が出る', (tester) async {
    final auth = FakeAuthGateway();
    addTearDown(auth.dispose);

    await _pumpProfile(
      tester,
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            await onboardingCompletedKeyValueStore(),
          ),
          authGatewayProvider.overrideWithValue(auth),
          remoteLearningStoreProvider.overrideWithValue(
            FakeRemoteLearningStore(),
          ),
        ],
        child: const AiPokerCoachApp(),
      ),
    );

    await _scrollTo(tester, find.text('アカウントと保存状況'));
    expect(find.text('メールで登録'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);

    await tester.tap(find.text('メールで登録'));
    await tester.pumpAndSettle();
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('登録する'), findsOneWidget);
  });
}
