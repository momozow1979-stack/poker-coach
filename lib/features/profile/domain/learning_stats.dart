import '../../../core/utils/date_x.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../../quiz/domain/quiz_category.dart';

/// 1 日分の正答率。推移グラフの 1 点になる。
class DailyAccuracy {
  const DailyAccuracy({
    required this.day,
    required this.accuracy,
    required this.answered,
  });

  final DateTime day;

  /// 0.0〜1.0。その日に回答が無ければ 0。
  final double accuracy;
  final int answered;

  bool get hasData => answered > 0;
}

/// カテゴリ別の正誤集計。Supabase の `learning_stats` に対応する。
class CategoryStat {
  const CategoryStat({
    required this.category,
    required this.correctCount,
    required this.incorrectCount,
  });

  final QuizCategory category;
  final int correctCount;
  final int incorrectCount;

  int get total => correctCount + incorrectCount;
  double get accuracy => total == 0 ? 0 : correctCount / total;

  /// 苦手判定に足るだけの回答数があるか。
  bool get hasEnoughSamples => total >= 3;
}

/// 学習履歴から算出する集計値。
class LearningStats {
  const LearningStats({
    required this.attempts,
    required this.reviewCount,
    required this.streakDays,
    required this.activeDaysLast7,
    required this.activeDaysLast30,
  });

  final List<QuizAttempt> attempts;
  final int reviewCount;
  final int streakDays;
  final int activeDaysLast7;
  final int activeDaysLast30;

  int get totalAnswered => attempts.length;
  int get totalCorrect => attempts.where((attempt) => attempt.isCorrect).length;
  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  /// カテゴリ別集計。回答のあるカテゴリのみ返す。
  List<CategoryStat> get categoryStats {
    final byCategory = <QuizCategory, List<QuizAttempt>>{};
    for (final attempt in attempts) {
      byCategory.putIfAbsent(attempt.category, () => []).add(attempt);
    }
    final stats = [
      for (final entry in byCategory.entries)
        CategoryStat(
          category: entry.key,
          correctCount: entry.value
              .where((attempt) => attempt.isCorrect)
              .length,
          incorrectCount: entry.value
              .where((attempt) => !attempt.isCorrect)
              .length,
        ),
    ];
    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return stats;
  }

  /// 問題 ID ごとの、最後に回答した日時。
  ///
  /// 「今日の10問」で直近に出した問題を除外するために使う。
  Map<String, DateTime> get lastAnsweredAt {
    final result = <String, DateTime>{};
    for (final attempt in attempts) {
      final current = result[attempt.quizId];
      if (current == null || attempt.answeredAt.isAfter(current)) {
        result[attempt.quizId] = attempt.answeredAt;
      }
    }
    return result;
  }

  /// 苦手分野。正答率が低く、かつ十分な回答数があるカテゴリ。
  List<QuizCategory> weakCategories({int limit = 3}) => [
    for (final stat in categoryStats)
      if (stat.hasEnoughSamples && stat.accuracy < 0.7) stat.category,
  ].take(limit).toList();

  /// 得意分野。
  List<QuizCategory> strongCategories({int limit = 3}) => [
    for (final stat in categoryStats.reversed)
      if (stat.hasEnoughSamples && stat.accuracy >= 0.8) stat.category,
  ].take(limit).toList();

  /// 直近 7 日の正答率。成長ポイントの算出に使う。
  double get accuracyLast7Days => _accuracySince(const Duration(days: 7));

  /// 8〜14 日前の正答率。直近との比較で「伸び」を出す。
  double get accuracyPreviousWeek {
    final window = _previousWeekAttempts;
    if (window.isEmpty) return 0;
    return window.where((attempt) => attempt.isCorrect).length / window.length;
  }

  /// 先週比を出せるだけのデータ（8〜14日前の回答）があるか。
  ///
  /// [accuracyPreviousWeek] は回答が無いときも 0 を返すため、
  /// 「本当に0%だった」のか「まだ比較できない」のかを区別するのに使う。
  bool get hasPreviousWeekData => _previousWeekAttempts.isNotEmpty;

  Iterable<QuizAttempt> get _previousWeekAttempts {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 14));
    final to = now.subtract(const Duration(days: 7));
    return attempts.where(
      (attempt) =>
          attempt.answeredAt.isAfter(from) && attempt.answeredAt.isBefore(to),
    );
  }

  double _accuracySince(Duration duration) {
    final from = DateTime.now().subtract(duration);
    final window = attempts.where(
      (attempt) => attempt.answeredAt.isAfter(from),
    );
    if (window.isEmpty) return 0;
    return window.where((attempt) => attempt.isCorrect).length / window.length;
  }

  /// 直近 [days] 日の日別正答率。回答のあった日だけを返す。
  ///
  /// 推移グラフに使うため、古い日から新しい日の順に並ぶ。
  List<DailyAccuracy> dailyAccuracy({int days = 14, DateTime? today}) {
    final base = (today ?? DateTime.now()).dateOnly;
    final byDay = <DateTime, List<QuizAttempt>>{};
    for (final attempt in attempts) {
      final day = attempt.answeredAt.dateOnly;
      if (base.difference(day).inDays >= days) continue;
      byDay.putIfAbsent(day, () => []).add(attempt);
    }

    final series = [
      for (final entry in byDay.entries)
        DailyAccuracy(
          day: entry.key,
          accuracy:
              entry.value.where((attempt) => attempt.isCorrect).length /
              entry.value.length,
          answered: entry.value.length,
        ),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return series;
  }

  /// 経験値からレベルを決める簡易ロジック。
  int get level => 1 + (totalCorrect ~/ 20) + (reviewCount ~/ 5);

  /// 次のレベルまでの進捗 (0.0〜1.0)。
  double get levelProgress {
    final points = totalCorrect + reviewCount * 4;
    return (points % 20) / 20;
  }
}
