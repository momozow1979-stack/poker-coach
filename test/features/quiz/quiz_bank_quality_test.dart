import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// 問題バンクの品質ルールを機械的に検証する。
///
/// 内容の正しさ自体は人のレビューでしか担保できないが、
/// 「前提が書かれていない」「解説が空」「数値の捏造」といった
/// 構造的な欠陥はここで止める。
void main() {
  final quizzes = QuizBank.all;

  /// 卓の状況を伴う問題だけ。用語問題には状況が無い。
  final situated = [
    for (final quiz in quizzes)
      if (quiz.situation case final situation?)
        (quiz: quiz, situation: situation),
  ];

  group('規模と構成', () {
    test('全カテゴリ30問ずつある', () {
      expect(quizzes, hasLength(QuizCategory.values.length * 30));
    });

    test('すべてのカテゴリに30問ずつある', () {
      for (final category in QuizCategory.values) {
        expect(
          QuizBank.byCategory(category),
          hasLength(30),
          reason: category.label,
        );
      }
    });

    test('問題 ID が重複していない', () {
      final ids = quizzes.map((quiz) => quiz.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('各カテゴリで難易度が3段階に分散している', () {
      for (final category in QuizCategory.values) {
        final byDifficulty = <QuizDifficulty, int>{};
        for (final quiz in QuizBank.byCategory(category)) {
          byDifficulty[quiz.difficulty] =
              (byDifficulty[quiz.difficulty] ?? 0) + 1;
        }
        for (final difficulty in QuizDifficulty.values) {
          expect(
            byDifficulty[difficulty] ?? 0,
            greaterThanOrEqualTo(5),
            reason: '${category.label} の ${difficulty.label} が少なすぎます',
          );
        }
      }
    });

    test('初心者が挫折しないよう、初級が最も多い', () {
      final counts = <QuizDifficulty, int>{};
      for (final quiz in quizzes) {
        counts[quiz.difficulty] = (counts[quiz.difficulty] ?? 0) + 1;
      }
      expect(
        counts[QuizDifficulty.beginner],
        greaterThanOrEqualTo(counts[QuizDifficulty.advanced]!),
      );
    });
  });

  group('選択肢と正解', () {
    test('すべての問題の正解が選択肢に含まれる', () {
      for (final quiz in quizzes) {
        expect(
          quiz.choices.map((choice) => choice.id),
          contains(quiz.correctChoiceId),
          reason: quiz.id,
        );
      }
    });

    test('選択肢は4つで、重複した文言が無い', () {
      for (final quiz in quizzes) {
        expect(quiz.choices, hasLength(4), reason: quiz.id);
        final labels = quiz.choices.map((choice) => choice.label).toList();
        expect(labels.toSet(), hasLength(4), reason: quiz.id);
        for (final label in labels) {
          expect(label.trim(), isNotEmpty, reason: quiz.id);
        }
      }
    });

    test('正解が常に同じ位置に偏っていない', () {
      final byIndex = <int, int>{};
      for (final quiz in quizzes) {
        final index = quiz.choices.indexWhere(
          (choice) => choice.id == quiz.correctChoiceId,
        );
        byIndex[index] = (byIndex[index] ?? 0) + 1;
      }
      // 4択なので均等なら各75問。極端な偏りだけを弾く。
      for (final entry in byIndex.entries) {
        expect(
          entry.value,
          lessThan(quizzes.length ~/ 2),
          reason: '正解が選択肢${entry.key}に${entry.value}問偏っています',
        );
      }
    });
  });

  group('前提の明記', () {
    test('相手のタイプが必ず書かれている', () {
      for (final entry in situated) {
        expect(
          entry.situation.villainProfile.trim(),
          isNotEmpty,
          reason: entry.quiz.id,
        );
      }
    });

    test('有効スタックが正の値で設定されている', () {
      for (final entry in situated) {
        expect(
          entry.situation.effectiveStackBb,
          greaterThan(0),
          reason: entry.quiz.id,
        );
      }
    });

    test('ポットが正の値で設定されている', () {
      for (final entry in situated) {
        expect(entry.situation.potBb, greaterThan(0), reason: entry.quiz.id);
      }
    });

    test('問題文にテーブルサイズが書かれている', () {
      for (final entry in situated) {
        final text =
            '${entry.quiz.question}${entry.situation.actionHistory.join()}';
        expect(
          text.contains('6MAX') || text.contains('9MAX') || text.contains('9人'),
          isTrue,
          reason: '${entry.quiz.id}: テーブルサイズが問題文にありません',
        );
      }
    });

    test('ヒーローのハンドは2枚', () {
      for (final entry in situated) {
        expect(entry.situation.heroCards, hasLength(2), reason: entry.quiz.id);
      }
    });

    test('ボードの枚数がストリートと一致している', () {
      const expected = {'preflop': 0, 'flop': 3, 'turn': 4, 'river': 5};
      for (final entry in situated) {
        expect(
          entry.situation.board.length,
          expected[entry.situation.street.id],
          reason: '${entry.quiz.id}: ${entry.situation.street.label}',
        );
      }
    });

    test('同じカードが2度使われていない', () {
      for (final entry in situated) {
        final cards = [...entry.situation.heroCards, ...entry.situation.board];
        expect(
          cards.map((card) => card.code).toSet(),
          hasLength(cards.length),
          reason: '${entry.quiz.id}: カードが重複しています',
        );
      }
    });

    test('状況が無いのは、板と関係のない定義問題だけ', () {
      // 板を読まないと答えられない設問から状況を外すと、答えようがなくなる。
      // 逆に、定義を聞くだけの設問に卓の図を出すと、
      // 初心者は「この board を読み取らないと答えられないのか」と誤解する。
      // 「リバースインプライドオッズ」のような複合語に当たらない語だけを見る。
      const boardWords = ['ボード', 'フロップ', '落ち', 'この場面', 'このハンド'];
      for (final quiz in quizzes) {
        if (quiz.situation != null) continue;
        for (final word in boardWords) {
          expect(
            quiz.question.contains(word),
            isFalse,
            reason:
                '${quiz.id}: 状況が無いのに問題文が「$word」に触れています。'
                '板を読まないと答えられない設問には状況が要ります',
          );
        }
      }
    });

    test('定義問題に、板と無関係な卓の状況を付けていない', () {
      // 「◯◯とは」だけを聞いていて、そのハンドや board に一切触れていないなら
      // 卓の図は要らない。図を出すと、初心者は
      // 「この board を読み取らないと答えられないのか」と誤解する。
      //
      // 状況を持つ問題は必ず先頭にテーブルサイズが入るので、
      // その定型部分を外してから中身を見る。
      final quotedDefinition = RegExp(r'「[^」]+」とは');
      final boilerplate = RegExp(r'^[69]MAX[^。]*。');
      const gameContent = [
        'ボード',
        '持って',
        'セット',
        'ペア',
        'ドロー',
        'スート',
        '枚',
        'フラッシュ',
        'ストレート',
      ];
      for (final quiz in quizzes) {
        if (quiz.situation == null) continue;
        if (!quotedDefinition.hasMatch(quiz.question)) continue;
        final body = quiz.question.replaceFirst(boilerplate, '');
        expect(
          gameContent.any(body.contains),
          isTrue,
          reason:
              '${quiz.id}: 定義を聞くだけの設問に卓の状況が付いています。'
              'buildDefinitionQuiz を使ってください',
        );
      }
    });
  });

  group('用語問題', () {
    final terms = QuizBank.byCategory(QuizCategory.terminology);

    test('卓の状況を持たない', () {
      for (final quiz in terms) {
        expect(quiz.situation, isNull, reason: quiz.id);
      }
    });

    test('「なぜ大事か」が意味の説明で終わっていない', () {
      // 用語の暗記で終わらせないため、重要性の説明に十分な長さを求める。
      for (final quiz in terms) {
        expect(
          quiz.explanation.gtoView.length,
          greaterThanOrEqualTo(60),
          reason: '${quiz.id}: なぜ大事かの説明が短すぎます',
        );
      }
    });

    test('同じ用語の意味を2度聞いていない', () {
      // 用語カテゴリを足したときに、既存のバンクにある定義問題と
      // 内容が重なることがある。「「◯◯」とは」の形の設問を突き合わせる。
      final asked = <String, String>{};
      final quoted = RegExp(r'「([^」]+)」とは');
      for (final quiz in quizzes) {
        final match = quoted.firstMatch(quiz.question);
        if (match == null) continue;
        final term = match.group(1)!;
        expect(
          asked[term],
          isNull,
          reason: '「$term」の意味を ${asked[term]} と ${quiz.id} の2問で聞いています',
        );
        asked[term] = quiz.id;
      }
    });

    test('初心者向けなので初級が一番多い', () {
      final counts = <QuizDifficulty, int>{};
      for (final quiz in terms) {
        counts[quiz.difficulty] = (counts[quiz.difficulty] ?? 0) + 1;
      }
      expect(
        counts[QuizDifficulty.beginner],
        greaterThan(counts[QuizDifficulty.advanced]!),
      );
    });
  });

  group('解説の品質', () {
    test('解説の4項目がすべて埋まっている', () {
      for (final quiz in quizzes) {
        expect(
          quiz.explanation.shortReason.trim(),
          isNotEmpty,
          reason: quiz.id,
        );
        expect(quiz.explanation.gtoView.trim(), isNotEmpty, reason: quiz.id);
        expect(
          quiz.explanation.practicalView.trim(),
          isNotEmpty,
          reason: quiz.id,
        );
        expect(
          quiz.explanation.commonMistake.trim(),
          isNotEmpty,
          reason: quiz.id,
        );
      }
    });

    test('「なぜ」を説明できる長さがある', () {
      for (final quiz in quizzes) {
        expect(
          quiz.explanation.shortReason.length,
          greaterThanOrEqualTo(25),
          reason: '${quiz.id}: 理由が短すぎます',
        );
      }
    });

    test('GTO の頻度を捏造していない', () {
      // 「GTO では 67.3% でベット」のような、根拠の無い頻度表現を禁止する
      //（仕様書 14-3 / docs/ai-prompts.md）。
      final fabricated = RegExp(
        r'(GTO|ソルバー|solver)[^。]{0,40}?[0-9]+(\.[0-9]+)?\s*%',
      );
      for (final quiz in quizzes) {
        for (final text in [
          quiz.explanation.shortReason,
          quiz.explanation.gtoView,
          quiz.explanation.practicalView,
          quiz.explanation.commonMistake,
        ]) {
          expect(
            fabricated.hasMatch(text),
            isFalse,
            reason: '${quiz.id}: GTO の頻度を数値で断定しています\n$text',
          );
        }
      }
    });

    test('EV の具体値を捏造していない', () {
      final fabricated = RegExp(r'EV\s*[はが＝=:：]?\s*[+\-−]?[0-9]');
      for (final quiz in quizzes) {
        for (final text in [
          quiz.explanation.shortReason,
          quiz.explanation.gtoView,
          quiz.explanation.practicalView,
          quiz.explanation.commonMistake,
        ]) {
          expect(
            fabricated.hasMatch(text),
            isFalse,
            reason: '${quiz.id}: EV 値を断定しています\n$text',
          );
        }
      }
    });

    test('関連レンジ表のリンク先 ID が命名規則に沿っている', () {
      final valid = RegExp(r'^(6max|9max)_[a-z+0-9]+_(open|defense)$');
      for (final quiz in quizzes) {
        final spotId = quiz.explanation.relatedRangeSpotId;
        if (spotId == null) continue;
        expect(valid.hasMatch(spotId), isTrue, reason: '${quiz.id}: $spotId');
      }
    });
  });

  group('状況の多様性', () {
    test('9MAX の問題も含まれている', () {
      final nineMax = situated.where(
        (entry) => entry.situation.tableType.id == '9max',
      );
      expect(nineMax, isNotEmpty);
    });

    test('100BB 以外のスタック深さも扱っている', () {
      final varied = situated.where(
        (entry) => entry.situation.effectiveStackBb != 100,
      );
      expect(varied.length, greaterThanOrEqualTo(20));
    });

    test('相手タイプが複数種類ある', () {
      final profiles = situated
          .map((entry) => entry.situation.villainProfile)
          .toSet();
      expect(profiles.length, greaterThanOrEqualTo(5));
    });

    test('すべてのストリートが出題される', () {
      final streets = situated
          .map((entry) => entry.situation.street.id)
          .toSet();
      expect(streets, hasLength(4));
    });
  });
}
