import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_repository.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/mock_quiz_repository.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「今日の10問が毎日同じものばかり出る」問題への回帰テスト。
void main() {
  const repository = MockQuizRepository();
  const cooldownDays = 14;

  /// [days] 日ぶん連続で出題し、各日の問題 ID を返す。
  ///
  /// 実際のアプリと同じように、出題した問題は履歴へ記録して次の日に渡す。
  List<List<String>> simulate(
    int days, {
    List<QuizCategory> weakCategories = const [],
    DateTime? from,
  }) {
    final start = from ?? DateTime(2026, 9, 1);
    final lastAnsweredAt = <String, DateTime>{};
    final result = <List<String>>[];

    for (var day = 0; day < days; day++) {
      final date = start.add(Duration(days: day));
      final quizzes = repository.dailyQuizzes(
        date,
        weakCategories: weakCategories,
        lastAnsweredAt: lastAnsweredAt,
      );
      result.add(quizzes.map((quiz) => quiz.id).toList());
      // その日の夜に全問回答した想定。
      for (final quiz in quizzes) {
        lastAnsweredAt[quiz.id] = date.add(const Duration(hours: 20));
      }
    }
    return result;
  }

  group('出題の重複回避', () {
    test('連続30日で、同じ問題の再出題まで十分な間隔が空く', () {
      final days = simulate(30);
      final lastSeen = <String, int>{};
      var minimumGap = 1 << 30;

      for (var day = 0; day < days.length; day++) {
        for (final id in days[day]) {
          final previous = lastSeen[id];
          if (previous != null) {
            final gap = day - previous;
            if (gap < minimumGap) minimumGap = gap;
          }
          lastSeen[id] = day;
        }
      }

      // 300 問のバンクなら 30 日ぶん（300 問）出しても一巡しないため、
      // そもそも再出題が発生しない。発生する場合もクールダウン以上空くこと。
      expect(
        minimumGap,
        greaterThanOrEqualTo(cooldownDays),
        reason: '再出題の最短間隔が $minimumGap 日でした',
      );
    });

    test('連続30日でバンクの大部分が出題される', () {
      final days = simulate(30);
      final all = days.expand((day) => day).toList();
      expect(all, hasLength(300));
      // クールダウン(14日)を過ぎた問題は再び候補に戻るため、
      // 30日ぶんがすべて別問題になるわけではない。
      // それでもバンク 300 問の大部分に到達していれば、
      // 「毎日同じ問題ばかり」にはならない。
      expect(
        all.toSet().length,
        greaterThanOrEqualTo(200),
        reason: '30日間で${all.toSet().length}問しか出題されていません',
      );
    });

    test('苦手カテゴリがあっても、連続30日で再出題の間隔が空く', () {
      final days = simulate(
        30,
        weakCategories: const [
          QuizCategory.turn,
          QuizCategory.river,
          QuizCategory.betSizing,
        ],
      );
      final lastSeen = <String, int>{};
      var minimumGap = 1 << 30;

      for (var day = 0; day < days.length; day++) {
        for (final id in days[day]) {
          final previous = lastSeen[id];
          if (previous != null) {
            minimumGap = day - previous < minimumGap
                ? day - previous
                : minimumGap;
          }
          lastSeen[id] = day;
        }
      }
      expect(minimumGap, greaterThanOrEqualTo(cooldownDays));
    });

    test('連続する2日で出題が大きく入れ替わる', () {
      final days = simulate(14);
      for (var day = 1; day < days.length; day++) {
        final overlap = days[day].toSet().intersection(days[day - 1].toSet());
        expect(
          overlap,
          isEmpty,
          reason: '${day - 1}日目と$day日目で${overlap.length}問が重複しています',
        );
      }
    });

    test('候補が10問を切る場合は、出題の古いものから順に戻す', () {
      // バンク全問を「昨日出題した」状態にすると、クールダウンで候補がゼロになる。
      // それでも 10 問を返せること（古い順に戻す動作）を確認する。
      final date = DateTime(2026, 9, 20);
      final lastAnsweredAt = {
        for (var i = 0; i < QuizBank.all.length; i++)
          QuizBank.all[i].id: date.subtract(Duration(days: 1 + (i % 13))),
      };

      final quizzes = repository.dailyQuizzes(
        date,
        lastAnsweredAt: lastAnsweredAt,
      );
      expect(quizzes, hasLength(10));

      // 戻すのは古いものから。13日前に出した問題が優先される。
      final elapsed = quizzes
          .map((quiz) => date.difference(lastAnsweredAt[quiz.id]!).inDays)
          .toList();
      expect(
        elapsed.every((days) => days >= 8),
        isTrue,
        reason: '新しく出したばかりの問題が戻されています: $elapsed',
      );
    });
  });

  group('苦手カテゴリの上限', () {
    test('苦手カテゴリからの出題は10問中4問まで', () {
      const weak = [
        QuizCategory.turn,
        QuizCategory.river,
        QuizCategory.betSizing,
      ];
      final lastAnsweredAt = <String, DateTime>{};

      for (var day = 0; day < 30; day++) {
        final date = DateTime(2026, 9, 1).add(Duration(days: day));
        final quizzes = repository.dailyQuizzes(
          date,
          weakCategories: weak,
          lastAnsweredAt: lastAnsweredAt,
        );
        final weakCount = quizzes
            .where((quiz) => weak.contains(quiz.category))
            .length;
        expect(
          weakCount,
          lessThanOrEqualTo(4),
          reason: '$day日目に苦手カテゴリが$weakCount問出ています',
        );
        for (final quiz in quizzes) {
          lastAnsweredAt[quiz.id] = date;
        }
      }
    });

    test('苦手カテゴリが1つだけでも4問を超えない', () {
      final quizzes = repository.dailyQuizzes(
        DateTime(2026, 9, 5),
        weakCategories: const [QuizCategory.preflop],
      );
      final weakCount = quizzes
          .where((quiz) => quiz.category == QuizCategory.preflop)
          .length;
      expect(weakCount, lessThanOrEqualTo(4));
    });

    test('苦手カテゴリは出題されるが、先頭に固まらない', () {
      const weak = [QuizCategory.river];
      var appearedOutsideHead = false;

      for (var day = 0; day < 20; day++) {
        final quizzes = repository.dailyQuizzes(
          DateTime(2026, 9, 1).add(Duration(days: day)),
          weakCategories: weak,
        );
        for (var i = 0; i < quizzes.length; i++) {
          if (quizzes[i].category == QuizCategory.river && i >= 4) {
            appearedOutsideHead = true;
          }
        }
      }
      expect(appearedOutsideHead, isTrue, reason: '苦手カテゴリが常に先頭に寄せられています');
    });
  });

  group('日付シードの維持', () {
    test('同じ日・同じ履歴なら何度呼んでも同じ10問', () {
      final date = DateTime(2026, 9, 12);
      final history = {
        for (final quiz in QuizBank.all.take(40))
          quiz.id: date.subtract(const Duration(days: 3)),
      };

      final first = repository.dailyQuizzes(date, lastAnsweredAt: history);
      final second = repository.dailyQuizzes(date, lastAnsweredAt: history);
      final third = repository.dailyQuizzes(date, lastAnsweredAt: history);

      expect(first.map((quiz) => quiz.id), second.map((quiz) => quiz.id));
      expect(first.map((quiz) => quiz.id), third.map((quiz) => quiz.id));
    });

    test('当日の回答が増えても、その日の10問は変わらない', () {
      final date = DateTime(2026, 9, 12);
      final before = repository.dailyQuizzes(date);

      // 当日ぶんを 5 問回答した状態を作る。
      final history = {
        for (final quiz in before.take(5))
          quiz.id: date.add(const Duration(hours: 21)),
      };
      final after = repository.dailyQuizzes(date, lastAnsweredAt: history);

      expect(
        after.map((quiz) => quiz.id),
        before.map((quiz) => quiz.id),
        reason: '途中で開き直すと出題が入れ替わってしまいます',
      );
    });

    test('日付が変わると出題も変わる', () {
      final today = repository.dailyQuizzes(DateTime(2026, 9, 12));
      final tomorrow = repository.dailyQuizzes(DateTime(2026, 9, 13));
      expect(
        today.map((quiz) => quiz.id).toList(),
        isNot(tomorrow.map((quiz) => quiz.id).toList()),
      );
    });
  });

  group('カテゴリの分散', () {
    test('10問が同一カテゴリに寄らない', () {
      for (var day = 0; day < 30; day++) {
        final quizzes = repository.dailyQuizzes(
          DateTime(2026, 9, 1).add(Duration(days: day)),
        );
        final counts = <QuizCategory, int>{};
        for (final quiz in quizzes) {
          counts[quiz.category] = (counts[quiz.category] ?? 0) + 1;
        }
        final maxInOneCategory = counts.values.reduce((a, b) => a > b ? a : b);
        expect(
          maxInOneCategory,
          lessThanOrEqualTo(maxPerCategoryOf(10)),
          reason: '$day日目: $counts',
        );
        expect(
          counts.keys.length,
          greaterThanOrEqualTo(4),
          reason: '$day日目のカテゴリ数が少なすぎます: $counts',
        );
      }
    });

    test('苦手カテゴリ指定時もカテゴリ数が確保される', () {
      final quizzes = repository.dailyQuizzes(
        DateTime(2026, 9, 3),
        weakCategories: const [QuizCategory.gto],
      );
      final categories = quizzes.map((quiz) => quiz.category).toSet();
      expect(categories.length, greaterThanOrEqualTo(4));
    });
  });

  group('引数の境界', () {
    test('count を変えても上限が比例して効く', () {
      final quizzes = repository.dailyQuizzes(
        DateTime(2026, 9, 7),
        count: 5,
        weakCategories: const [QuizCategory.flop],
      );
      expect(quizzes, hasLength(5));
      final weakCount = quizzes
          .where((quiz) => quiz.category == QuizCategory.flop)
          .length;
      expect(weakCount, lessThanOrEqualTo(weakQuotaOf(5)));
    });

    test('count が 0 以下なら空を返す', () {
      expect(repository.dailyQuizzes(DateTime(2026, 9, 7), count: 0), isEmpty);
    });

    test('未来日の回答記録があっても10問を返す', () {
      final date = DateTime(2026, 9, 7);
      final quizzes = repository.dailyQuizzes(
        date,
        lastAnsweredAt: {
          for (final quiz in QuizBank.all)
            quiz.id: date.add(const Duration(days: 5)),
        },
      );
      expect(quizzes, hasLength(10));
      expect(quizzes.map((quiz) => quiz.id).toSet(), hasLength(10));
    });
  });

  group('weakQuotaOf / maxPerCategoryOf', () {
    test('10問なら苦手枠4問・1カテゴリ上限4問', () {
      expect(weakQuotaOf(10), 4);
      expect(maxPerCategoryOf(10), 4);
    });

    test('少ない出題数でも下限を割らない', () {
      expect(weakQuotaOf(1), 1);
      expect(maxPerCategoryOf(1), 1);
      expect(maxPerCategoryOf(5), greaterThanOrEqualTo(2));
    });
  });
}
