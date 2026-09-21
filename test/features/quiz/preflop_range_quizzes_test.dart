import 'package:ai_poker_coach/features/quiz/infrastructure/banks/preflop_range_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('レンジ表から生成したプリフロップ出題', () {
    final generated = PreflopRangeQuizzes.all;

    test('十分な数を生成している', () {
      expect(generated.length, greaterThanOrEqualTo(60));
    });

    test('QuizBank 全体で ID が重複しない', () {
      final ids = QuizBank.all.map((q) => q.id).toList();
      expect(ids.length, ids.toSet().length, reason: 'ID の重複がある');
    });

    test('各問が構造的に正しい（選択肢・正解・4点解説・関連レンジ）', () {
      for (final q in generated) {
        expect(q.choices.length, 4, reason: q.id);
        expect(
          q.choices.any((c) => c.id == q.correctChoiceId),
          isTrue,
          reason: '${q.id}: 正解 ID が選択肢に無い',
        );
        expect(q.situation, isNotNull, reason: q.id);
        expect(q.explanation.shortReason, isNotEmpty, reason: q.id);
        expect(q.explanation.gtoView, isNotEmpty, reason: q.id);
        expect(q.explanation.practicalView, isNotEmpty, reason: q.id);
        expect(q.explanation.commonMistake, isNotEmpty, reason: q.id);
        expect(q.explanation.relatedRangeSpotId, isNotNull, reason: q.id);
      }
    });

    test('正解はレンジ表と一致している（既知スポットの抜き取り検証）', () {
      String labelOf(String id) {
        final q = generated.firstWhere((q) => q.id == id);
        return q.correctChoice.label;
      }

      // オープン: UTG は狭い → AA はレイズ / 72o はフォールド。
      expect(labelOf('pfr-o-utg-AA'), 'Raise 2.5BB');
      expect(labelOf('pfr-o-utg-72o'), 'Fold');
      // vsオープン: BB vs BTN → AA は 3ベット / 72o はフォールド。
      expect(labelOf('pfr-v-bb-AA'), '3Bet');
      expect(labelOf('pfr-v-bb-72o'), 'Fold');
    });
  });
}
