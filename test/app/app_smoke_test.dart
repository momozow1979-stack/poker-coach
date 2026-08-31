import 'package:ai_poker_coach/app/app.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_choice_button.dart';
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

    for (final section in ['理由', 'GTO視点', '実戦での調整', 'よくある初心者のミス']) {
      await _scrollTo(tester, find.text(section));
      expect(find.text(section), findsOneWidget, reason: section);
    }

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

  testWidgets('レビュータブで2つのモードから選べる', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レビュー');

    expect(find.text('意思決定トレーナー'), findsOneWidget);
    expect(find.text('自分のハンドをレビュー'), findsOneWidget);
  });

  testWidgets('レビュータブ → 自分のハンド入力は未入力だと実行できない', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'レビュー');

    await _scrollTo(tester, find.text('入力を始める'));
    await tester.tap(find.text('入力を始める'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('AIレビューを実行'));

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('AIレビューを実行'),
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
