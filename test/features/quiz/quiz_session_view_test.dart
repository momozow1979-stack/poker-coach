import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_choice_button.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_session_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Quiz _quizWithChoices() {
  return Quiz(
    id: 'shuffle-test',
    category: QuizCategory.preflop,
    difficulty: QuizDifficulty.beginner,
    question: 'テスト問題',
    choices: const [
      QuizChoice(id: 'c0', label: '選択肢A（正解）'),
      QuizChoice(id: 'c1', label: '選択肢B'),
      QuizChoice(id: 'c2', label: '選択肢C'),
      QuizChoice(id: 'c3', label: '選択肢D'),
    ],
    correctChoiceId: 'c0',
    explanation: const QuizExplanation(
      shortReason: 'テストの理由',
      gtoView: 'テストのGTO視点',
      practicalView: 'テストの実戦視点',
      commonMistake: 'テストのミス',
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Quiz quiz, {
  String? selectedChoiceId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: QuizSessionView(
          quiz: quiz,
          selectedChoiceId: selectedChoiceId,
          onAnswer: (_) {},
          onNext: () {},
          onOpenRange: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QuizSessionView の選択肢表示順', () {
    testWidgets('データ上の全選択肢がそのまま表示される（並び順に関わらず）', (tester) async {
      await _pump(tester, _quizWithChoices());

      final labels = tester
          .widgetList<QuizChoiceButton>(find.byType(QuizChoiceButton))
          .map((w) => w.label)
          .toSet();

      expect(labels, {'選択肢A（正解）', '選択肢B', '選択肢C', '選択肢D'});
    });

    testWidgets('正解の選択肢が毎回同じ位置（先頭）には固定されない', (tester) async {
      var sawNonFirst = false;

      for (var i = 0; i < 30; i++) {
        await _pump(tester, _quizWithChoices());
        final buttons = tester
            .widgetList<QuizChoiceButton>(find.byType(QuizChoiceButton))
            .toList();
        final correctIndex = buttons.indexWhere((b) => b.isCorrectChoice);
        if (correctIndex != 0) {
          sawNonFirst = true;
          break;
        }
      }

      expect(
        sawNonFirst,
        isTrue,
        reason: '30回試して一度も先頭以外に来ないのは、シャッフルが効いていない可能性が高いです',
      );
    });

    testWidgets('同じ問題を表示している間（回答して再ビルドされても）表示順は変わらない', (tester) async {
      await _pump(tester, _quizWithChoices());
      final before = tester
          .widgetList<QuizChoiceButton>(find.byType(QuizChoiceButton))
          .map((w) => w.label)
          .toList();

      // 回答後の状態（selectedChoiceId あり）で再ビルドされても、
      // 表示順が回答のたびに入れ替わってはいけない。
      await _pump(tester, _quizWithChoices(), selectedChoiceId: 'c0');
      final after = tester
          .widgetList<QuizChoiceButton>(find.byType(QuizChoiceButton))
          .map((w) => w.label)
          .toList();

      expect(after, before);
    });
  });
}
