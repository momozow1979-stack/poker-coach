import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/learning_json.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('保存した履歴の読み戻し', () {
    test('HandReviewInput は JSON を往復しても同じ内容になる', () {
      final input = HandReviewInput(
        gameType: GameType.tournament,
        tableType: TableType.nineMax,
        smallBlind: 1,
        bigBlind: 2,
        effectiveStackBb: 45,
        heroPosition: Position.co,
        heroHand: PlayingCard.parseAll(const ['Qs', 'Jh']),
        villainPosition: Position.sb,
        villainProfile: VillainProfile.aggressive,
        environment: PlayEnvironment.live,
        preflop: const [
          HandAction(
            actor: HandAction.heroActor,
            action: PokerActionType.raise,
            sizeBb: 2.5,
          ),
          HandAction(actor: 'SB', action: PokerActionType.threeBet),
        ],
        flop: StreetInput(
          cards: PlayingCard.parseAll(const ['2c', '7d', 'Ts']),
          actions: const [
            HandAction(actor: 'SB', action: PokerActionType.bet50),
          ],
        ),
        turn: StreetInput(cards: PlayingCard.parseAll(const ['Ah'])),
        userQuestion: 'ターンでコールすべきでしたか？',
      );

      final restored = HandReviewInput.fromJson(input.toJson());

      expect(restored.gameType, GameType.tournament);
      expect(restored.tableType, TableType.nineMax);
      expect(restored.effectiveStackBb, 45);
      expect(restored.heroPosition, Position.co);
      expect(PlayingCard.encodeAll(restored.heroHand), ['Qs', 'Jh']);
      expect(restored.villainPosition, Position.sb);
      expect(restored.villainProfile, VillainProfile.aggressive);
      expect(restored.environment, PlayEnvironment.live);
      expect(restored.preflop, hasLength(2));
      expect(restored.preflop.first.action, PokerActionType.raise);
      expect(restored.preflop.first.sizeBb, 2.5);
      expect(restored.preflop.last.actor, 'SB');
      expect(PlayingCard.encodeAll(restored.flop.cards), ['2c', '7d', 'Ts']);
      expect(restored.flop.actions.single.action, PokerActionType.bet50);
      expect(PlayingCard.encodeAll(restored.turn.cards), ['Ah']);
      expect(restored.river.cards, isEmpty);
      expect(restored.userQuestion, 'ターンでコールすべきでしたか？');
    });

    test('レビュー 1 件は JSON を往復しても同じ内容になる', () {
      final review = fakeReview(id: 'r-1', createdAt: DateTime(2026, 8, 31, 9));
      final restored = LearningJson.reviewFromJson(
        LearningJson.reviewToJson(review),
      )!;

      expect(restored.id, 'r-1');
      expect(restored.createdAt, DateTime(2026, 8, 31, 9));
      expect(restored.score, 72);
      expect(restored.result.summary, 'テスト用のレビュー');
      expect(restored.title, review.title);
    });

    test('クイズ回答は JSON を往復しても同じ内容になる', () {
      final attempt = fakeAttempt(
        quizId: 'turn-012',
        answeredAt: DateTime(2026, 8, 30, 21, 30),
        isCorrect: false,
      );
      final restored = LearningJson.attemptFromJson(
        LearningJson.attemptToJson(attempt),
      )!;

      expect(restored.quizId, 'turn-012');
      expect(restored.answeredAt, DateTime(2026, 8, 30, 21, 30));
      expect(restored.isCorrect, isFalse);
      expect(restored.category, attempt.category);
      expect(restored.selectedChoiceId, attempt.selectedChoiceId);
    });

    test('壊れた JSON は null になり、履歴全体を巻き込まない', () {
      expect(LearningJson.attemptFromJson(const {}), isNull);
      expect(
        LearningJson.attemptFromJson(const {
          'quiz_key': 'q',
          'answered_at': '',
        }),
        isNull,
      );
      expect(LearningJson.reviewFromJson(const {'id': 'x'}), isNull);
    });
  });
}
