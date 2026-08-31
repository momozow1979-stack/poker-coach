import 'dart:math';

import '../../../core/utils/date_x.dart';
import '../domain/quiz.dart';
import '../domain/quiz_category.dart';
import '../domain/quiz_repository.dart';
import 'quiz_bank.dart';

/// アプリ同梱のクイズを返すリポジトリ。
///
/// Phase 4 で Supabase の `quizzes` テーブルに置き換える。
class MockQuizRepository implements QuizRepository {
  const MockQuizRepository();

  @override
  List<Quiz> all() => QuizBank.all;

  @override
  List<Quiz> byCategory(QuizCategory category) =>
      QuizBank.all.where((quiz) => quiz.category == category).toList();

  /// その日の出題を組み立てる。
  ///
  /// 手順は 4 段階。
  /// 1. 直近 [cooldownDays] 日に出した問題を候補から外す（足りなければ古い順に戻す）。
  /// 2. カテゴリごとのラウンドロビンに並べ替えて、10 問が 1 カテゴリに寄らないようにする。
  /// 3. 苦手カテゴリから上限ぶんだけ取り、残りをそれ以外のカテゴリで埋める。
  /// 4. 日付シードでシャッフルして順番を決める。
  ///
  /// 乱数は日付だけをシードにしているため、同じ日・同じ履歴なら必ず同じ 10 問になる。
  @override
  List<Quiz> dailyQuizzes(
    DateTime date, {
    int count = 10,
    List<QuizCategory> weakCategories = const [],
    Map<String, DateTime> lastAnsweredAt = const {},
    int cooldownDays = 14,
  }) {
    final pool = QuizBank.all;
    if (pool.isEmpty || count <= 0) return const [];

    final target = min(count, pool.length);
    // 日付をシードにして、同じ日なら必ず同じ 10 問になるようにする。
    final random = Random(_seedFor(date));

    final eligible = _eligible(
      pool,
      date,
      lastAnsweredAt,
      cooldownDays,
      target,
    );
    // カテゴリ順に 1 問ずつ拾う並びにしておくと、先頭から取るだけで分散する。
    final spread = _spreadByCategory(eligible, random);

    final weakSet = weakCategories.toSet();
    final weakFirst = spread
        .where((quiz) => weakSet.contains(quiz.category))
        .toList();
    final others = spread
        .where((quiz) => !weakSet.contains(quiz.category))
        .toList();

    final picked = <Quiz>[];
    final perCategory = <QuizCategory, int>{};
    final maxPerCategory = maxPerCategoryOf(target);

    // 苦手カテゴリ枠。上限を超えて先頭に居座らせない。
    _fill(
      picked,
      perCategory,
      weakFirst,
      min(weakQuotaOf(target), target),
      maxPerCategory,
    );
    // 残りは苦手以外から。ここが日替わりで入れ替わる。
    _fill(picked, perCategory, others, target, maxPerCategory);
    // カテゴリ上限で埋まりきらないときだけ上限を外す。
    _fill(picked, perCategory, others, target, null);
    // 苦手以外が尽きている場合の最終手段。苦手枠の上限より問題数の確保を優先する。
    _fill(picked, perCategory, spread, target, null);

    // 苦手カテゴリが常に先頭に並ばないよう、最後に順番を混ぜる。
    picked.shuffle(random);
    return picked;
  }

  static int _seedFor(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  /// 直近に出していない問題を返す。
  ///
  /// [target] 問に満たない場合は、出題が古いものから順に戻す。
  /// 当日ぶんの回答は判定に含めない。含めてしまうと、
  /// 数問答えたあとに開き直したときに残りの問題が入れ替わってしまうため。
  static List<Quiz> _eligible(
    List<Quiz> pool,
    DateTime date,
    Map<String, DateTime> lastAnsweredAt,
    int cooldownDays,
    int target,
  ) {
    final today = date.dateOnly;
    final fresh = <Quiz>[];
    final cooling = <_Cooling>[];

    for (final quiz in pool) {
      final answeredAt = lastAnsweredAt[quiz.id];
      if (answeredAt == null) {
        fresh.add(quiz);
        continue;
      }
      final elapsed = today.difference(answeredAt.dateOnly).inDays;
      // elapsed <= 0 は当日ぶん（と未来日の記録）。クールダウンの対象外にする。
      if (elapsed <= 0 || elapsed >= cooldownDays) {
        fresh.add(quiz);
      } else {
        cooling.add(_Cooling(elapsed, quiz));
      }
    }

    if (fresh.length >= target) return fresh;

    // 経過日数が大きい = 出題が古いものから戻す。同点は ID 順で安定させる。
    cooling.sort((a, b) {
      final byElapsed = b.elapsedDays.compareTo(a.elapsedDays);
      return byElapsed != 0 ? byElapsed : a.quiz.id.compareTo(b.quiz.id);
    });
    for (final entry in cooling) {
      if (fresh.length >= target) break;
      fresh.add(entry.quiz);
    }
    return fresh;
  }

  /// カテゴリごとに 1 問ずつ拾うラウンドロビン順に並べ替える。
  ///
  /// 先頭から [target] 問取るだけでカテゴリが分散するので、
  /// 「10 問すべて同じカテゴリ」が構造的に起きなくなる。
  static List<Quiz> _spreadByCategory(List<Quiz> quizzes, Random random) {
    final byCategory = <QuizCategory, List<Quiz>>{};
    for (final quiz in quizzes) {
      byCategory.putIfAbsent(quiz.category, () => []).add(quiz);
    }

    final categories = byCategory.keys.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    categories.shuffle(random);
    for (final category in categories) {
      byCategory[category]!.shuffle(random);
    }

    final ordered = <Quiz>[];
    for (var round = 0; ordered.length < quizzes.length; round++) {
      for (final category in categories) {
        final bucket = byCategory[category]!;
        if (round < bucket.length) ordered.add(bucket[round]);
      }
    }
    return ordered;
  }

  /// [source] から [limit] 問に達するまで詰める。
  ///
  /// [maxPerCategory] が null ならカテゴリ上限を無視する。
  static void _fill(
    List<Quiz> picked,
    Map<QuizCategory, int> perCategory,
    List<Quiz> source,
    int limit,
    int? maxPerCategory,
  ) {
    if (picked.length >= limit) return;
    final chosen = picked.map((quiz) => quiz.id).toSet();
    for (final quiz in source) {
      if (picked.length >= limit) return;
      if (!chosen.add(quiz.id)) continue;
      final used = perCategory[quiz.category] ?? 0;
      if (maxPerCategory != null && used >= maxPerCategory) continue;
      picked.add(quiz);
      perCategory[quiz.category] = used + 1;
    }
  }
}

/// クールダウン中の問題と、その経過日数。
class _Cooling {
  const _Cooling(this.elapsedDays, this.quiz);

  final int elapsedDays;
  final Quiz quiz;
}
