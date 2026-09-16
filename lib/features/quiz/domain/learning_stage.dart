import '../../profile/domain/learning_stats.dart';
import 'quiz_category.dart';

/// 学習プランの5ステージ。
///
/// 既存の11カテゴリを「覚えるべき分野」で束ねて、
/// 「今どこにいて、次に何を学ぶか」を見せる。
/// 以前は3ステージで、街の進行（フロップ/ターン/リバー）と
/// 計算系の話（ポットオッズ/ベットサイズ）を1段階に混ぜていたが、
/// 性質の違う分野が混在してわかりにくかったため5段階に分け直した。
enum LearningStage {
  basics('基礎知識', [QuizCategory.position, QuizCategory.terminology]),
  preflop('プリフロップ', [QuizCategory.preflop]),
  boardReading('ボードの見極め', [
    QuizCategory.flop,
    QuizCategory.turn,
    QuizCategory.river,
  ]),
  math('数字で考える', [QuizCategory.potOdds, QuizCategory.betSizing]),
  advanced('応用・駆け引き', [
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

  /// [category] が属するステージ。
  static LearningStage forCategory(QuizCategory category) =>
      values.firstWhere((stage) => stage.categories.contains(category));
}
