import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_choice_button.dart';
import 'package:ai_poker_coach/shared/widgets/collapsible_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // このテストはオンボーディング導入前の動線（タブが最初から見える）を
  // 検証するため、pump 前にオンボーディング完了済みの状態を注入する。
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

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ホームが表示され、5つのタブが並ぶ', (tester) async {
    await _pumpApp(tester);

    expect(find.text('今日の10問'), findsWidgets);
    expect(find.text('AIコーチ'), findsOneWidget);
    for (final label in ['ホーム', '学習', 'レンジ', 'レビュー', 'マイページ']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('ホームの「今日の10問を始める」からクイズへ遷移する', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('今日の10問を始める'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10'), findsOneWidget);
  });

  testWidgets('クイズに回答すると4つの観点の解説が出る', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, '学習');

    expect(find.text('1 / 10'), findsOneWidget);

    await _scrollTo(tester, find.byType(QuizChoiceButton));
    await tester.tap(find.byType(QuizChoiceButton).first);
    await tester.pumpAndSettle();

    // 見出しは問題の種類で変わる（用語問題は「なぜ大事か」など）ので、
    // 文言ではなく「理由 + 折りたたみ3つ」で確認する。
    await _scrollTo(tester, find.text('理由'));
    expect(find.text('理由'), findsOneWidget);
    await _scrollTo(tester, find.byType(CollapsibleSection));
    expect(find.byType(CollapsibleSection), findsNWidgets(3));

    await _scrollTo(tester, find.text('次の問題へ'));
    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('レンジタブで13x13マトリクスとテーブル切替が動く', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レンジ');

    expect(find.text('AA'), findsWidgets);
    expect(find.text('9MAX'), findsOneWidget);

    await tester.tap(find.text('9MAX'));
    await tester.pumpAndSettle();
    expect(find.text('UTG+1'), findsOneWidget);
  });

  testWidgets('レンジ表のハンドをタップすると詳細シートが開く', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レンジ');

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();

    expect(find.text('なぜこのアクションか'), findsOneWidget);
    expect(find.text('初心者向け'), findsOneWidget);
    expect(find.text('GTO解説'), findsOneWidget);
    expect(find.text('実戦での調整'), findsOneWidget);
  });

  testWidgets('レビュータブは自分のハンドレビュー専用になっている', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レビュー');

    // 汎用トレーニング機能（ハンドトレーナー）への導線は無い。
    expect(find.text('意思決定トレーナー'), findsNothing);
    expect(find.text('ハンドトレーナー'), findsNothing);
    // 自分のハンドをレビューする導線だけがある。
    expect(find.text('ハンドをレビューする'), findsWidgets);
    expect(find.text('まだレビューがありません'), findsOneWidget);
  });

  testWidgets('レビュータブ → 自分のハンド入力は未入力だと実行できない', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レビュー');

    await _scrollTo(tester, find.text('入力を始める'));
    await tester.tap(find.text('入力を始める'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('レビューを実行'));

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('レビューを実行'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('マイページに学習統計が並ぶ', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'マイページ');

    expect(find.text('連続学習'), findsOneWidget);
    expect(find.text('総合正答率'), findsOneWidget);

    await _scrollTo(tester, find.text('カテゴリ別の正答率'));
    expect(find.text('カテゴリ別の正答率'), findsOneWidget);
  });
}
