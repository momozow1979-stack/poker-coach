import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_choice_button.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('QuizChoiceButton', () {
    testWidgets('actionType が設定されていればアクションアイコンを表示する', (tester) async {
      await _pump(
        tester,
        QuizChoiceButton(
          label: 'Raise 2.5BB',
          actionType: PokerActionType.raise,
          isRevealed: false,
          isCorrectChoice: false,
          isSelected: false,
          onTap: () {},
        ),
      );

      expect(find.byIcon(PokerActionType.raise.icon), findsOneWidget);
      expect(find.text('Raise 2.5BB'), findsOneWidget);
    });

    testWidgets('actionType が null ならアクションアイコンを表示しない', (tester) async {
      await _pump(
        tester,
        QuizChoiceButton(
          label: '「アウツ」とは何か',
          isRevealed: false,
          isCorrectChoice: false,
          isSelected: false,
          onTap: () {},
        ),
      );

      for (final action in PokerActionType.values) {
        expect(find.byIcon(action.icon), findsNothing, reason: action.name);
      }
    });

    testWidgets('回答後も正解/不正解の色付けが優先して表示される', (tester) async {
      await _pump(
        tester,
        QuizChoiceButton(
          label: 'Fold',
          actionType: PokerActionType.fold,
          isRevealed: true,
          isCorrectChoice: true,
          isSelected: true,
          onTap: null,
        ),
      );
      await tester.pumpAndSettle();

      // アクションアイコンは残るが、正解を示す丸チェックも同時に出る。
      expect(find.byIcon(PokerActionType.fold.icon), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('不正解時は cancel アイコンが表示される', (tester) async {
      await _pump(
        tester,
        QuizChoiceButton(
          label: 'Call',
          actionType: PokerActionType.call,
          isRevealed: true,
          isCorrectChoice: false,
          isSelected: true,
          onTap: null,
        ),
      );

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });
  });
}
