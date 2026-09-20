import 'package:flutter_test/flutter_test.dart';
import 'package:ai_poker_coach/features/hand_review/domain/camera_hand_assignment.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/domain/read_hand_result.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';

void main() {
  group('ReadHandResult.fromJson', () {
    test('カード・警告をパースし、10をTに正規化する', () {
      final result = ReadHandResult.fromJson({
        'cards': [
          {'code': 'Ah', 'confidence': 0.9, 'suggested': 'me'},
          {'code': '10s', 'confidence': 0.8, 'suggested': 'board', 'board_order': 1},
          {'code': 'Kd', 'confidence': 0.7, 'suggested': 'villain', 'cluster': 2},
          {'code': 'ZZ', 'confidence': 0.1, 'suggested': 'board'},
        ],
        'warnings': ['1枚読めませんでした'],
      });
      // 不正コード(ZZ)は捨てられる。
      expect(result.cards.length, 3);
      expect(result.cards[1].card, PlayingCard.parse('Ts'));
      expect(result.cards[2].suggested, ReadCardRole.villain);
      expect(result.cards[2].cluster, 2);
      expect(result.warnings, ['1枚読めませんでした']);
    });
  });

  group('initialAssignments / applyAssignments', () {
    ReadHandCard c(String code, ReadCardRole role, {int? order, int? cluster}) =>
        ReadHandCard(
          card: PlayingCard.parse(code),
          confidence: 0.95,
          suggested: role,
          boardOrder: order,
          cluster: cluster,
        );

    test('リバーまでの5枚+相手2人を正しく仕分ける', () {
      final result = ReadHandResult(cards: [
        c('Ah', ReadCardRole.me),
        c('Js', ReadCardRole.me),
        c('Qs', ReadCardRole.board, order: 1),
        c('7d', ReadCardRole.board, order: 2),
        c('2c', ReadCardRole.board, order: 3),
        c('9h', ReadCardRole.board, order: 4),
        c('Ts', ReadCardRole.board, order: 5),
        c('Kd', ReadCardRole.villain, cluster: 1),
        c('Ks', ReadCardRole.villain, cluster: 1),
        c('8c', ReadCardRole.villain, cluster: 2),
        c('8d', ReadCardRole.villain, cluster: 2),
      ]);
      final assignments = initialAssignments(result);
      expect(hasSlotWarning(assignments), isFalse);

      final input = applyAssignments(const HandReviewInput(), assignments);
      expect(input.heroHand, [PlayingCard.parse('Ah'), PlayingCard.parse('Js')]);
      expect(input.flop.cards.length, 3);
      expect(input.turn.cards, [PlayingCard.parse('9h')]);
      expect(input.river.cards, [PlayingCard.parse('Ts')]);
      // ヘッズアップ前提なので、レビューに使うのは相手1(最小index)の2枚。
      expect(input.villainHand, [PlayingCard.parse('Kd'), PlayingCard.parse('Ks')]);
    });

    test('フロップで降りた(場3枚・相手なし)場合もエラーにならない', () {
      final result = ReadHandResult(cards: [
        c('Ah', ReadCardRole.me),
        c('Js', ReadCardRole.me),
        c('Qs', ReadCardRole.board, order: 1),
        c('7d', ReadCardRole.board, order: 2),
        c('2c', ReadCardRole.board, order: 3),
      ]);
      final assignments = initialAssignments(result);
      expect(hasSlotWarning(assignments), isFalse);

      final input = applyAssignments(const HandReviewInput(), assignments);
      expect(input.flop.cards.length, 3);
      expect(input.turn.cards, isEmpty);
      expect(input.river.cards, isEmpty);
      expect(input.villainHand, isEmpty);
    });

    test('リバーだけあってターンが無いと警告になる', () {
      final assignments = [
        AssignedCard(card: PlayingCard.parse('Ah'), confidence: 1, slot: HandSlot.hero),
        AssignedCard(card: PlayingCard.parse('Js'), confidence: 1, slot: HandSlot.hero),
        AssignedCard(card: PlayingCard.parse('Qs'), confidence: 1, slot: HandSlot.flop),
        AssignedCard(card: PlayingCard.parse('7d'), confidence: 1, slot: HandSlot.flop),
        AssignedCard(card: PlayingCard.parse('2c'), confidence: 1, slot: HandSlot.flop),
        AssignedCard(card: PlayingCard.parse('Ts'), confidence: 1, slot: HandSlot.river),
      ];
      expect(hasSlotWarning(assignments), isTrue);
    });
  });
}
