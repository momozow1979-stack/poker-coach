import 'package:ai_poker_coach/features/quiz/application/quiz_providers.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_repository.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/mock_quiz_repository.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizBank', () {
    test('すべての問題の正解が選択肢に含まれる', () {
      for (final quiz in QuizBank.all) {
        expect(
          quiz.choices.map((choice) => choice.id),
          contains(quiz.correctChoiceId),
          reason: quiz.id,
        );
      }
    });

    test('問題 ID が重複していない', () {
      final ids = QuizBank.all.map((quiz) => quiz.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('解説の4項目がすべて埋まっている', () {
      for (final quiz in QuizBank.all) {
        expect(quiz.explanation.shortReason, isNotEmpty, reason: quiz.id);
        expect(quiz.explanation.gtoView, isNotEmpty, reason: quiz.id);
        expect(quiz.explanation.practicalView, isNotEmpty, reason: quiz.id);
        expect(quiz.explanation.commonMistake, isNotEmpty, reason: quiz.id);
      }
    });

    test('10問を出題できるだけの問題数がある', () {
      expect(QuizBank.all.length, greaterThanOrEqualTo(10));
    });
  });

  group('MockQuizRepository', () {
    const repository = MockQuizRepository();

    test('同じ日付なら同じ10問になる', () {
      final first = repository.dailyQuizzes(DateTime(2026, 8, 29));
      final second = repository.dailyQuizzes(DateTime(2026, 8, 29));
      expect(first.map((quiz) => quiz.id), second.map((quiz) => quiz.id));
      expect(first, hasLength(10));
    });

    test('日付が変わると出題も変わる', () {
      final today = repository.dailyQuizzes(DateTime(2026, 8, 29));
      final tomorrow = repository.dailyQuizzes(DateTime(2026, 8, 30));
      expect(
        today.map((quiz) => quiz.id).toList(),
        isNot(tomorrow.map((quiz) => quiz.id).toList()),
      );
    });

    test('苦手カテゴリは10問中4問までに制限される', () {
      final quizzes = repository.dailyQuizzes(
        DateTime(2026, 8, 29),
        weakCategories: const [QuizCategory.river, QuizCategory.turn],
      );
      final weakCount = quizzes
          .where(
            (quiz) =>
                quiz.category == QuizCategory.river ||
                quiz.category == QuizCategory.turn,
          )
          .length;
      expect(weakCount, lessThanOrEqualTo(weakQuotaOf(10)));
    });
  });

  group('DailyQuizController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('回答すると解説が開き、次へ進める', () {
      final controller = container.read(dailyQuizSessionProvider.notifier);
      final quiz = container.read(dailyQuizSessionProvider).currentQuiz!;

      controller.answer(quiz.correctChoiceId);
      var session = container.read(dailyQuizSessionProvider);
      expect(session.isAnswerRevealed, isTrue);
      expect(session.correctCount, 1);
      expect(session.currentIndex, 0);

      controller.next();
      session = container.read(dailyQuizSessionProvider);
      expect(session.isAnswerRevealed, isFalse);
      expect(session.currentIndex, 1);
    });

    test('解説表示中は二重回答できない', () {
      final controller = container.read(dailyQuizSessionProvider.notifier);
      final quiz = container.read(dailyQuizSessionProvider).currentQuiz!;
      final wrongChoice = quiz.choices.firstWhere(
        (choice) => choice.id != quiz.correctChoiceId,
      );

      controller.answer(quiz.correctChoiceId);
      controller.answer(wrongChoice.id);

      expect(
        container.read(dailyQuizSessionProvider).revealedChoiceId,
        quiz.correctChoiceId,
      );
    });

    test('回答は学習履歴に記録される', () {
      final before = container.read(learningStoreProvider).attempts.length;
      final controller = container.read(dailyQuizSessionProvider.notifier);
      final quiz = container.read(dailyQuizSessionProvider).currentQuiz!;

      controller.answer(quiz.correctChoiceId);

      expect(container.read(learningStoreProvider).attempts.length, before + 1);
    });

    test('10問すべて答えると終了状態になる', () {
      final controller = container.read(dailyQuizSessionProvider.notifier);
      for (var i = 0; i < 10; i++) {
        final quiz = container.read(dailyQuizSessionProvider).currentQuiz!;
        controller.answer(quiz.correctChoiceId);
        controller.next();
      }
      final session = container.read(dailyQuizSessionProvider);
      expect(session.isFinished, isTrue);
      expect(session.currentQuiz, isNull);
      expect(session.accuracy, 1.0);
    });

    test('やり直すと進捗がリセットされる', () {
      final controller = container.read(dailyQuizSessionProvider.notifier);
      final quiz = container.read(dailyQuizSessionProvider).currentQuiz!;
      controller.answer(quiz.correctChoiceId);
      controller.next();
      controller.restart();

      final session = container.read(dailyQuizSessionProvider);
      expect(session.answeredCount, 0);
      expect(session.currentIndex, 0);
    });
  });
}
