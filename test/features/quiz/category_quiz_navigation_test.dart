import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_choice_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/onboarding_test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = await onboardingCompletedKeyValueStore(
    answers: fakeOnboardingAnswers(
      focusCategories: const [QuizCategory.preflop],
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
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
  testWidgets('苦手分野が未検出のうちは「学びたい分野」がホームに出て、タップで復習に遷移する', (tester) async {
    await _pumpApp(tester);

    await _scrollTo(tester, find.text('学びたい分野'));
    expect(find.text('学びたい分野'), findsOneWidget);
    expect(find.text('プリフロップ'), findsWidgets);

    await _scrollTo(tester, find.text('プリフロップ').last);
    await tester.tap(find.text('プリフロップ').last);
    await tester.pumpAndSettle();

    expect(find.text('プリフロップを復習'), findsOneWidget);

    // 実際に1問答えられる（今日の10問と同じ出題・解説の仕組みを使っている）。
    await _scrollTo(tester, find.byType(QuizChoiceButton));
    await tester.tap(find.byType(QuizChoiceButton).first);
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('理由'));
    expect(find.text('理由'), findsOneWidget);
  });
}
