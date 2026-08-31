import '../domain/quiz.dart';
import '../domain/quiz_category.dart';
import 'banks/bet_sizing_quizzes.dart';
import 'banks/exploit_quizzes.dart';
import 'banks/flop_quizzes.dart';
import 'banks/gto_quizzes.dart';
import 'banks/position_quizzes.dart';
import 'banks/pot_odds_quizzes.dart';
import 'banks/preflop_quizzes.dart';
import 'banks/river_quizzes.dart';
import 'banks/turn_quizzes.dart';
import 'banks/value_bluff_quizzes.dart';

/// アプリに同梱するクイズ。Phase 4 で Supabase の `quizzes` テーブルへ移す。
///
/// カテゴリごとに `banks/` 配下のファイルへ分割している。
/// 各問題は次のルールで作成する。
/// - テーブルサイズ・有効スタック・ポジション・相手タイプを必ず明示する
/// - ソルバーの厳密な頻度や EV 値は書かない（仕様書 14-3 / docs/ai-prompts.md）
/// - 数値を使うのは、計算で確定するものだけ
///   （ポットオッズ、必要勝率、アウツ、SPR、組み合わせの数え上げ）
/// - 解説は「短い理由 / GTO視点 / 実戦視点 / よくあるミス」の 4 点セット
abstract final class QuizBank {
  static List<Quiz> get all => _all;

  /// カテゴリごとの問題。出題ロジックの分散処理で使う。
  static List<Quiz> byCategory(QuizCategory category) =>
      _all.where((quiz) => quiz.category == category).toList();

  static final List<Quiz> _all = List.unmodifiable([
    ...PreflopQuizzes.all,
    ...FlopQuizzes.all,
    ...TurnQuizzes.all,
    ...RiverQuizzes.all,
    ...PositionQuizzes.all,
    ...BetSizingQuizzes.all,
    ...PotOddsQuizzes.all,
    ...ValueBluffQuizzes.all,
    ...GtoQuizzes.all,
    ...ExploitQuizzes.all,
  ]);
}
