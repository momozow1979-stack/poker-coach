import 'package:ai_poker_coach/features/quiz/infrastructure/banks/combo_count_quizzes.dart';
import 'package:ai_poker_coach/shared/models/combo_counter.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('コンボ数え上げ出題', () {
    final quizzes = ComboCountQuizzes.all;

    test('生成されている', () {
      expect(quizzes, isNotEmpty);
    });

    test('各問は4択で、正解が含まれ、解説が埋まっている', () {
      for (final q in quizzes) {
        expect(q.choices.length, 4, reason: q.id);
        expect(q.choices.map((c) => c.label).toSet().length, 4, reason: q.id);
        expect(
          q.choices.any((c) => c.id == q.correctChoiceId),
          isTrue,
          reason: q.id,
        );
        expect(q.situation, isNotNull, reason: q.id);
        expect(q.explanation.shortReason, isNotEmpty, reason: q.id);
      }
    });

    test('正解の数字が ComboCounter と一致している（＝捏造でない）', () {
      // 出題文から対象ハンドと、見えているカード（ヒーロー＋ボード）を取り出し、
      // ComboCounter で数え直して、正解ラベルと突き合わせる。
      for (final q in quizzes) {
        final situation = q.situation!;
        final dead = <PlayingCard>[...situation.heroCards, ...situation.board];
        // 正解ラベルは「N通り」。
        final label = q.correctChoice.label;
        final n = int.parse(label.replaceAll('通り', ''));
        // 問題文中の対象コード（「XX（…）を持つ」の XX）を探す。
        final match = RegExp(r'相手が ([2-9TJQKA]{2}[so]?)（')
            .firstMatch(q.question);
        expect(match, isNotNull, reason: q.id);
        final target = StartingHand.parse(match!.group(1)!);
        expect(
          ComboCounter.combos(target, dead: dead),
          n,
          reason: '${q.id}: 正解 $label が ComboCounter と一致しない',
        );
      }
    });
  });
}
