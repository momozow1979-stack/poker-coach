import 'package:ai_poker_coach/features/quiz/infrastructure/banks/bet_sizing_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/exploit_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/flop_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/position_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/pot_odds_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/preflop_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/river_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/turn_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/value_bluff_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選択肢に付与した [PokerActionType] タグの品質を機械的に検証する。
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

  /// ファイル全体で一括して `tagActionTypes: true` にしているカテゴリ。
  ///
  /// これらは「選択肢が一貫してアクション語で書かれている」ことを確認済みで、
  /// 概念的な選択肢（英語のアクション語を含まない）は素朴なキーワード一覧に
  /// 引っかからないぶん、ここでの検証もそのまま成立する。
  final blanketTaggedQuizzes = [
    ...PreflopQuizzes.all,
    ...FlopQuizzes.all,
    ...TurnQuizzes.all,
    ...RiverQuizzes.all,
    ...BetSizingQuizzes.all,
    ...PotOddsQuizzes.all,
    ...ValueBluffQuizzes.all,
    ...ExploitQuizzes.all,
  ];

  group('一括タグ付けカテゴリ（preflop/flop/turn/river/bet_sizing/pot_odds/value_bluff/exploit）', () {
    test('英語のアクション語を含む選択肢には actionType が付いている', () {
      final untagged = <String>[];
      for (final quiz in blanketTaggedQuizzes) {
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
      for (final quiz in blanketTaggedQuizzes) {
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

    test('タグ付けされた選択肢が一定数以上ある（仕組みが機能している）', () {
      final taggedCount = blanketTaggedQuizzes
          .expand((quiz) => quiz.choices)
          .where((choice) => choice.actionType != null)
          .length;
      expect(taggedCount, greaterThan(500));
    });
  });

  group('ポジション問題（アクション選択肢と理論問題が混在するカテゴリ）', () {
    // ポジション問題は「Fold/Call/Raise/All-in」のようなアクション選択肢と、
    // ポジション理論そのものを問う概念的な選択肢（日本語の説明文）が混在する。
    // そのため一括タグ付けはせず、選択肢がアクション語だけで構成されている
    // 設問だけを個別に列挙して確認する。
    const taggedQuizIds = [
      'ps001',
      'ps004',
      'ps006',
      'ps008',
      'ps010',
      'ps011',
      'ps012',
      'ps014',
      'ps016',
      'ps018',
      'ps019',
      'ps020',
      'ps021',
      'ps023',
      'ps029',
    ];

    test('個別に有効化した設問はすべての選択肢に actionType が付いている', () {
      final byId = {for (final q in PositionQuizzes.all) q.id: q};
      final untagged = <String>[];
      for (final id in taggedQuizIds) {
        final quiz = byId[id]!;
        for (final choice in quiz.choices) {
          if (choice.actionType == null) {
            untagged.add('${quiz.id}: ${choice.label}');
          }
        }
      }
      expect(
        untagged,
        isEmpty,
        reason:
            'タグ付け対象にした設問に、actionType が付いていない選択肢があります:\n'
            '${untagged.join('\n')}',
      );
    });

    test('タグ付けしていない設問には actionType を付けていない', () {
      final byId = {for (final q in PositionQuizzes.all) q.id: q};
      final wronglyTagged = <String>[];
      for (final quiz in PositionQuizzes.all) {
        if (taggedQuizIds.contains(quiz.id)) continue;
        for (final choice in quiz.choices) {
          if (choice.actionType != null) {
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
            'タグ付け対象外の設問に actionType が付いています:\n'
            '${wronglyTagged.join('\n')}',
      );
      // byId は上のループで使っていないが、id 抜けが無いことの確認に使う。
      expect(byId.length, PositionQuizzes.all.length);
    });

    test('ps028（"必ず 3Bet すべきになる"）は概念的な選択肢のため意図的にタグ付けしていない', () {
      // 深いスタックが判断に与える影響を問う理論問題。選択肢の一つに
      // 「3Bet」という単語が文中に埋め込まれているが、これはアクションの
      // 選択ではなく効果の説明文なので、force-fit しない。
      // inferActionType は素朴な部分文字列一致のため、もしこの設問を
      // 誤ってタグ付け対象に含めてしまうと「3Bet」の部分だけ誤タグが
      // 付いてしまう ── その回帰を防ぐガードテスト。
      final quiz = PositionQuizzes.all.firstWhere((q) => q.id == 'ps028');
      expect(
        quiz.choices.any((c) => c.label.contains('3Bet')),
        isTrue,
        reason: 'この設問の前提（3Bet を含む選択肢がある）が変わっています。テストを見直してください。',
      );
      for (final choice in quiz.choices) {
        expect(
          choice.actionType,
          isNull,
          reason: '${quiz.id}: ${choice.label} に actionType を付けるべきではありません',
        );
      }
    });
  });

  test('GTO・用語カテゴリは選択肢が概念的なため actionType を付けていない', () {
    // gto_quizzes は「なぜそうなるか」を問う理論問題、terminology_quizzes は
    // 用語の定義問題で、どちらも卓の状況に基づくアクション選択ではない。
    final taggedInSkippedCategories = <String>[];
    for (final quiz in QuizBank.all) {
      if (quiz.category.id != 'gto' && quiz.category.id != 'terminology') {
        continue;
      }
      for (final choice in quiz.choices) {
        if (choice.actionType != null) {
          taggedInSkippedCategories.add('${quiz.id}: ${choice.label}');
        }
      }
    }
    expect(
      taggedInSkippedCategories,
      isEmpty,
      reason:
          'GTO・用語カテゴリは概念問題のみのため actionType を付けない方針です。'
          '方針を変えたなら、このテストの期待値も更新してください:\n'
          '${taggedInSkippedCategories.join('\n')}',
    );
  });
}
