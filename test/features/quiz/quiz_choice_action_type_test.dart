import 'package:ai_poker_coach/features/quiz/infrastructure/banks/flop_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/preflop_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter_test/flutter_test.dart';

/// プリフロップ / フロップの選択肢に付与した [PokerActionType] タグの
/// 品質を機械的に検証する。
///
/// 実装（`quiz_builder.dart` の `inferActionType`）と同じロジックを
/// ここで再実装すると、実装のバグごとテストも一緒に通ってしまい
/// 意味が無くなる。そのため、ここでは独立した・より単純な
/// 「英語のアクション語を含んでいるなら、タグが付いているはず」という
/// 素朴なキーワード一覧だけで検証する（誤検出を避けるため、
/// 概念的な選択肢に現れない語だけを選んでいる）。
void main() {
  const actionKeywords = [
    'Fold',
    'Call',
    'Raise',
    'Re-raise',
    'Bet',
    'All-in',
    'Check',
    'Check-Raise',
    '3Bet',
    '4Bet',
  ];

  group('プリフロップ / フロップの選択肢のアクションタグ付け', () {
    test('英語のアクション語を含む選択肢には actionType が付いている', () {
      final untagged = <String>[];
      for (final quiz in [...PreflopQuizzes.all, ...FlopQuizzes.all]) {
        for (final choice in quiz.choices) {
          final looksLikeAction = actionKeywords.any(choice.label.contains);
          if (looksLikeAction && choice.actionType == null) {
            untagged.add('${quiz.id}: ${choice.label}');
          }
        }
      }
      expect(
        untagged,
        isEmpty,
        reason:
            'アクションを表す選択肢に actionType が付いていません:\n'
            '${untagged.join('\n')}',
      );
    });

    test('概念的な選択肢（アクション語を含まない）には actionType を付けていない', () {
      // 「相手のベットを待つ」のような、アクションそのものではない選択肢に
      // 無理にタグを付けていないことを確認する（force-fit しない方針）。
      final wronglyTagged = <String>[];
      for (final quiz in [...PreflopQuizzes.all, ...FlopQuizzes.all]) {
        for (final choice in quiz.choices) {
          final looksLikeAction = actionKeywords.any(choice.label.contains);
          if (!looksLikeAction && choice.actionType != null) {
            wronglyTagged.add(
              '${quiz.id}: ${choice.label} -> ${choice.actionType}',
            );
          }
        }
      }
      expect(
        wronglyTagged,
        isEmpty,
        reason:
            '概念的な選択肢にアクション種別を無理に当てはめています:\n'
            '${wronglyTagged.join('\n')}',
      );
    });

    test('他のカテゴリは今回のスコープ外なので actionType を付けていない', () {
      // プリフロップ・フロップ以外は、内容確認がまだ済んでいないため
      // 今回は意図的に手を付けていない。将来ここを広げる際は、
      // この期待値ごと更新すること。
      final otherCategoryQuizzes = QuizBank.all.where(
        (quiz) => quiz.category.id != 'preflop' && quiz.category.id != 'flop',
      );
      final tagged = <String>[];
      for (final quiz in otherCategoryQuizzes) {
        for (final choice in quiz.choices) {
          if (choice.actionType != null) {
            tagged.add('${quiz.id}: ${choice.label}');
          }
        }
      }
      expect(
        tagged,
        isEmpty,
        reason:
            'プリフロップ・フロップ以外にも actionType が付いています。'
            'スコープを広げたなら、このテストの期待値も更新してください:\n'
            '${tagged.join('\n')}',
      );
    });

    test('タグ付けされた選択肢が一定数以上ある（仕組みが機能している）', () {
      final taggedCount = [...PreflopQuizzes.all, ...FlopQuizzes.all]
          .expand((quiz) => quiz.choices)
          .where((choice) => choice.actionType != null)
          .length;
      expect(taggedCount, greaterThan(100));
    });
  });
}
