import 'quiz.dart';
import 'quiz_category.dart';

/// クイズの取得口。Mock と Supabase 実装を差し替えられるようにする。
abstract interface class QuizRepository {
  /// 出題可能なクイズすべて。
  List<Quiz> all();

  /// その日の 10 問。同じ日付・同じ履歴・同じ [excludeIds] なら必ず同じ並びになる。
  ///
  /// - [weakCategories] は優先的に出題するが、[weakQuotaOf] 問までに制限する。
  ///   毎日同じ問題が先頭に居座らないようにするため。
  /// - [lastAnsweredAt] は問題 ID ごとの最終回答日時。
  ///   [cooldownDays] 日以内に出した問題は候補から外す。
  ///   外しすぎて候補が [count] を切る場合は、古いものから順に戻す。
  /// - [excludeIds] は、クールダウンとは別に強制的に除外する問題 ID。
  ///   「今日すでに見せた問題」を、同じ日のうちにもう一度出したくない
  ///   （＝新しい 10 問に挑戦する）場合に使う。
  List<Quiz> dailyQuizzes(
    DateTime date, {
    int count = 10,
    List<QuizCategory> weakCategories = const [],
    Map<String, DateTime> lastAnsweredAt = const {},
    int cooldownDays = 14,
    Set<String> excludeIds = const {},
  });

  /// カテゴリを指定して復習する（クイズ解説やレビュー結果からの導線）。
  List<Quiz> byCategory(QuizCategory category);
}

/// [count] 問中、苦手カテゴリに割り当てる上限。
///
/// 10 問なら 4 問。残りは日替わりで回すことで、
/// 苦手カテゴリの問題が毎日固定で出続けるのを防ぐ。
int weakQuotaOf(int count) => count <= 2 ? count : (count * 2 / 5).floor();

/// [count] 問中、1 カテゴリが占めてよい上限。10 問なら 4 問。
int maxPerCategoryOf(int count) {
  if (count <= 2) return count;
  final quota = weakQuotaOf(count);
  return quota < 2 ? 2 : quota;
}
