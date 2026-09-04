import 'package:ai_poker_coach/core/utils/date_x.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stats.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_attempt.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:flutter_test/flutter_test.dart';

QuizAttempt _attempt({
  required QuizCategory category,
  required bool isCorrect,
  int daysAgo = 0,
}) {
  return QuizAttempt(
    quizId: 'q-$category-$isCorrect-$daysAgo',
    category: category,
    selectedChoiceId: 'c0',
    isCorrect: isCorrect,
    answeredAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  );
}

void main() {
  group('calculateStreak', () {
    final today = DateTime(2026, 8, 29);

    test('今日から連続している日数を数える', () {
      final days = {
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(calculateStreak(days, today: today), 3);
    });

    test('昨日までの連続も継続中として数える', () {
      final days = {
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      };
      expect(calculateStreak(days, today: today), 2);
    });

    test('2日以上空いていたら途切れる', () {
      final days = {today.subtract(const Duration(days: 2))};
      expect(calculateStreak(days, today: today), 0);
    });

    test('履歴が無ければ0', () {
      expect(calculateStreak({}, today: today), 0);
    });
  });

  group('LearningStats', () {
    test('カテゴリ別の正答率を集計する', () {
      final stats = LearningStats(
        attempts: [
          _attempt(category: QuizCategory.turn, isCorrect: false),
          _attempt(category: QuizCategory.turn, isCorrect: false, daysAgo: 1),
          _attempt(category: QuizCategory.turn, isCorrect: true, daysAgo: 2),
          _attempt(category: QuizCategory.preflop, isCorrect: true),
          _attempt(category: QuizCategory.preflop, isCorrect: true, daysAgo: 1),
          _attempt(category: QuizCategory.preflop, isCorrect: true, daysAgo: 2),
        ],
        reviewCount: 0,
        streakDays: 3,
        activeDaysLast7: 3,
        activeDaysLast30: 3,
      );

      expect(stats.totalAnswered, 6);
      expect(stats.totalCorrect, 4);
      expect(stats.weakCategories(), [QuizCategory.turn]);
      expect(stats.strongCategories(), [QuizCategory.preflop]);
    });

    test('回答数が3問未満のカテゴリは苦手判定しない', () {
      final stats = LearningStats(
        attempts: [
          _attempt(category: QuizCategory.river, isCorrect: false),
          _attempt(category: QuizCategory.river, isCorrect: false, daysAgo: 1),
        ],
        reviewCount: 0,
        streakDays: 1,
        activeDaysLast7: 1,
        activeDaysLast30: 1,
      );
      expect(stats.weakCategories(), isEmpty);
    });

    test('先週ぶんのデータが無ければ hasPreviousWeekData は false', () {
      final stats = LearningStats(
        attempts: [_attempt(category: QuizCategory.preflop, isCorrect: true)],
        reviewCount: 0,
        streakDays: 1,
        activeDaysLast7: 1,
        activeDaysLast30: 1,
      );
      expect(stats.hasPreviousWeekData, isFalse);
      // データが無いときは 0 を返すが、これは「本当に0%だった」わけではない。
      expect(stats.accuracyPreviousWeek, 0);
    });

    test('8〜14日前に回答があれば hasPreviousWeekData は true で正答率も出る', () {
      final stats = LearningStats(
        attempts: [
          _attempt(category: QuizCategory.preflop, isCorrect: true, daysAgo: 9),
          _attempt(
            category: QuizCategory.preflop,
            isCorrect: false,
            daysAgo: 10,
          ),
        ],
        reviewCount: 0,
        streakDays: 0,
        activeDaysLast7: 0,
        activeDaysLast30: 2,
      );
      expect(stats.hasPreviousWeekData, isTrue);
      expect(stats.accuracyPreviousWeek, 0.5);
    });

    test('レベルは正解数とレビュー件数から決まる', () {
      final stats = LearningStats(
        attempts: [
          for (var i = 0; i < 40; i++)
            _attempt(category: QuizCategory.gto, isCorrect: true, daysAgo: i),
        ],
        reviewCount: 5,
        streakDays: 1,
        activeDaysLast7: 1,
        activeDaysLast30: 1,
      );
      expect(stats.level, 1 + 2 + 1);
    });
  });
}
