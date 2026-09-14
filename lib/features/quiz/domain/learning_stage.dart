import '../../profile/domain/learning_stats.dart';
import 'quiz_category.dart';

/// 学習ロードマップの 3 ステージ。
///
/// 既存の 11 カテゴリを「基礎／ポストフロップ／応用」に束ねて、
/// 「今どこにいて、次に何を学ぶか」を地図として見せる。
enum LearningStage {
  foundations('基礎', [
    QuizCategory.preflop,
    QuizCategory.position,
    QuizCategory.terminology,
  ]),
  postflop('ポストフロップ', [
    QuizCategory.flop,
    QuizCategory.turn,
    QuizCategory.river,
    QuizCategory.potOdds,
    QuizCategory.betSizing,
  ]),
  advanced('応用', [
    QuizCategory.valueBluff,
    QuizCategory.gto,
    QuizCategory.exploit,
  ]);

  const LearningStage(this.label, this.categories);

  final String label;
  final List<QuizCategory> categories;

  String get categoryLabels => categories.map((c) => c.label).join('・');

  /// このステージに属する回答の正解数・回答数。
  ({int correct, int total}) progressFrom(List<CategoryStat> categoryStats) {
    var correct = 0;
    var total = 0;
    for (final stat in categoryStats) {
      if (!categories.contains(stat.category)) continue;
      correct += stat.correctCount;
      total += stat.total;
    }
    return (correct: correct, total: total);
  }
}
