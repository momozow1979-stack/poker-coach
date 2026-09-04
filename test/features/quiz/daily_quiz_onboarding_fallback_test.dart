import 'package:ai_poker_coach/features/onboarding/application/onboarding_providers.dart';
import 'package:ai_poker_coach/features/onboarding/domain/onboarding_answers.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/user_profile.dart';
import 'package:ai_poker_coach/features/quiz/application/quiz_providers.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_repository.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

/// `dailyQuizzes` に渡された `weakCategories` をそのまま記録するだけの偽リポジトリ。
class _RecordingQuizRepository implements QuizRepository {
  List<QuizCategory>? capturedWeakCategories;

  @override
  List<Quiz> all() => QuizBank.all;

  @override
  List<Quiz> byCategory(QuizCategory category) =>
      QuizBank.all.where((quiz) => quiz.category == category).toList();

  @override
  List<Quiz> dailyQuizzes(
    DateTime date, {
    int count = 10,
    List<QuizCategory> weakCategories = const [],
    Map<String, DateTime> lastAnsweredAt = const {},
    int cooldownDays = 14,
  }) {
    capturedWeakCategories = weakCategories;
    return QuizBank.all.take(count).toList();
  }
}

class _FixedOnboardingAnswersNotifier extends OnboardingAnswersNotifier {
  _FixedOnboardingAnswersNotifier(this._value);

  final OnboardingAnswers? _value;

  @override
  OnboardingAnswers? build() => _value;
}

void main() {
  group('DailyQuizController: 苦手分野が未検出のときのオンボーディング代替出題', () {
    test('苦手分野が空なら、オンボーディングの学びたい分野が weakCategories として渡る', () {
      final repository = _RecordingQuizRepository();
      final container = ProviderContainer(
        overrides: [
          quizRepositoryProvider.overrideWithValue(repository),
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(
              OnboardingAnswers(
                pokerLevel: PokerLevel.novice,
                focusCategories: const [QuizCategory.river, QuizCategory.turn],
                completedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(dailyQuizSessionProvider);

      expect(repository.capturedWeakCategories, [
        QuizCategory.river,
        QuizCategory.turn,
      ]);
    });

    test('オンボーディング未完了（null）なら空リストのまま', () {
      final repository = _RecordingQuizRepository();
      final container = ProviderContainer(
        overrides: [
          quizRepositoryProvider.overrideWithValue(repository),
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(dailyQuizSessionProvider);

      expect(repository.capturedWeakCategories, isEmpty);
    });

    test('実際の苦手分野が検出されていれば、オンボーディングの回答より優先される', () {
      final repository = _RecordingQuizRepository();
      final container = ProviderContainer(
        overrides: [
          quizRepositoryProvider.overrideWithValue(repository),
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(
              OnboardingAnswers(
                pokerLevel: PokerLevel.novice,
                focusCategories: const [QuizCategory.gto],
                completedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // river を3問不正解にして苦手判定を成立させる。
      final store = container.read(learningStoreProvider.notifier);
      for (var i = 0; i < 3; i++) {
        store.recordAttempt(
          fakeAttempt(
            quizId: 'river-fallback-test-$i',
            answeredAt: DateTime.now(),
            isCorrect: false,
            category: QuizCategory.river,
          ),
        );
      }

      container.read(dailyQuizSessionProvider);

      expect(repository.capturedWeakCategories, [QuizCategory.river]);
    });
  });
}
