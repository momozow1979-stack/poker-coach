import 'package:ai_poker_coach/features/quiz/domain/daily_quiz_session.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('onOpenTrainer を渡すと「他の練習」カードが出て、タップで呼ばれる', (tester) async {
    var tapped = false;
    final session = DailyQuizSession(
      date: DateTime(2026, 1, 1),
      quizzes: QuizBank.all.take(1).toList(),
    );

    await tester.pumpWidget(
      wrap(
        QuizSummaryView(
          session: session,
          onRestart: () {},
          onGoHome: () {},
          onOpenTrainer: () => tapped = true,
        ),
      ),
    );

    expect(find.text('他の練習: ハンドトレーナー'), findsOneWidget);
    await tester.tap(find.text('他の練習: ハンドトレーナー'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('onOpenTrainer を渡さなければカードは出ない', (tester) async {
    final session = DailyQuizSession(
      date: DateTime(2026, 1, 1),
      quizzes: QuizBank.all.take(1).toList(),
    );

    await tester.pumpWidget(
      wrap(
        QuizSummaryView(session: session, onRestart: () {}, onGoHome: () {}),
      ),
    );

    expect(find.text('他の練習: ハンドトレーナー'), findsNothing);
  });
}
