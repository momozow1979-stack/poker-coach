import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

HandAction _a(String actor, PokerActionType type, [double? size]) =>
    HandAction(actor: actor, action: type, sizeBb: size);

const hero = HandAction.heroActor;

void main() {
  group('行動順', () {
    test('BTN vs BB はプリフロップで BTN が先、フロップ以降も BTN が後', () {
      final input = HandReviewInput(
        heroPosition: Position.btn,
        villainPosition: Position.bb,
        heroHand: PlayingCard.parseAll(['Ah', 'Qs']),
      );
      final flow = HandFlow(input);
      expect(flow.firstActorOf(Street.preflop), Actor.hero);
      expect(flow.firstActorOf(Street.flop), Actor.villain);
    });

    test('BB vs BTN はプリフロップで BTN（相手）が先', () {
      final input = HandReviewInput(
        heroPosition: Position.bb,
        villainPosition: Position.btn,
        heroHand: PlayingCard.parseAll(['Ah', 'Qs']),
      );
      final flow = HandFlow(input);
      expect(flow.firstActorOf(Street.preflop), Actor.villain);
      expect(flow.firstActorOf(Street.flop), Actor.hero);
    });
  });

  group('入力の進み方', () {
    HandReviewInput base() => HandReviewInput(
      heroPosition: Position.btn,
      villainPosition: Position.bb,
      heroHand: PlayingCard.parseAll(['Ah', 'Qs']),
    );

    test('ハンド未入力ならまずハンドを求める', () {
      expect(HandFlow(const HandReviewInput()).step, isA<NeedHeroHand>());
    });

    test('最初はプリフロップの、あなたのアクションを求める', () {
      final step = HandFlow(base()).step as NeedAction;
      expect(step.prompt.street, Street.preflop);
      expect(step.prompt.actor, Actor.hero);
      expect(step.prompt.position, Position.btn);
      // BB を払わないと参加できないので、賭けに直面している。
      expect(step.prompt.facingBet, isTrue);
      expect(step.prompt.toCallBb, 1);
      expect(step.prompt.potBb, 1.5);
      expect(step.prompt.aggressiveLabel, 'レイズ');
      // BB を埋めるだけなので、必要勝率の話にはしない。
      expect(step.prompt.isBlindOnly, isTrue);
      expect(step.prompt.requiredEquity, isNull);
    });

    test('レイズしたら次は相手の番になり、呼び名が3ベットに変わる', () {
      final input = base().copyWith(
        preflop: [_a(hero, PokerActionType.raise, 2.5)],
      );
      final step = HandFlow(input).step as NeedAction;
      expect(step.prompt.actor, Actor.villain);
      expect(step.prompt.facingBet, isTrue);
      expect(step.prompt.toCallBb, 1.5);
      expect(step.prompt.aggressiveLabel, '3ベット');
      // 相手が自分の意思で上げた額なので、ここからは必要勝率が意味を持つ。
      expect(step.prompt.isBlindOnly, isFalse);
      expect(step.prompt.requiredEquity, closeTo(1.5 / 5.5, 1e-9));
    });

    test('レイズ→コールでプリフロップが終わり、フロップの3枚を求める', () {
      final input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.raise, 2.5),
          _a('BB', PokerActionType.call),
        ],
      );
      final step = HandFlow(input).step as NeedBoard;
      expect(step.street, Street.flop);
      expect(step.count, 3);
    });

    test('リンプにはBBのオプションが残るので、まだ終わらない', () {
      final input = base().copyWith(preflop: [_a(hero, PokerActionType.call)]);
      final step = HandFlow(input).step as NeedAction;
      expect(step.prompt.actor, Actor.villain);
      expect(step.prompt.facingBet, isFalse);
    });

    test('リンプ→チェックでプリフロップが終わる', () {
      final input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.call),
          _a('BB', PokerActionType.check),
        ],
      );
      expect(HandFlow(input).step, isA<NeedBoard>());
    });

    test('フォールドしたらそこで終わり', () {
      final input = base().copyWith(preflop: [_a(hero, PokerActionType.fold)]);
      final step = HandFlow(input).step as ReviewReady;
      expect(step.endedByFold, isTrue);
      expect(step.foldedBy, Actor.hero);
      expect(step.sawShowdown, isFalse);
    });

    test('フロップは OOP の相手から始まり、チェック2回で終わる', () {
      var input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.raise, 2.5),
          _a('BB', PokerActionType.call),
        ],
        flop: StreetInput(cards: PlayingCard.parseAll(['Ad', '7c', '2s'])),
      );
      var step = HandFlow(input).step as NeedAction;
      expect(step.prompt.actor, Actor.villain);
      expect(step.prompt.facingBet, isFalse);
      expect(step.prompt.potBb, 5.5);

      input = input.copyWith(
        flop: input.flop.copyWith(
          actions: [
            _a('BB', PokerActionType.check),
            _a(hero, PokerActionType.check),
          ],
        ),
      );
      expect(HandFlow(input).step, isA<NeedBoard>());
    });

    test('ポットとコール額がサイズから計算される', () {
      final input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.raise, 2.5),
          _a('BB', PokerActionType.call),
        ],
        flop: StreetInput(
          cards: PlayingCard.parseAll(['Ad', '7c', '2s']),
          actions: [
            _a('BB', PokerActionType.check),
            _a(hero, PokerActionType.bet, 2),
          ],
        ),
      );
      final step = HandFlow(input).step as NeedAction;
      expect(step.prompt.actor, Actor.villain);
      // 5.5 + 2 = 7.5
      expect(step.prompt.potBb, 7.5);
      expect(step.prompt.toCallBb, 2);
      expect(step.prompt.requiredEquity, closeTo(2 / 9.5, 1e-9));
    });

    test('サイズが分からないと、それ以降のポットは不明になる', () {
      final input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.raise),
          _a('BB', PokerActionType.call),
        ],
        flop: StreetInput(cards: PlayingCard.parseAll(['Ad', '7c', '2s'])),
      );
      final step = HandFlow(input).step as NeedAction;
      expect(step.prompt.potBb, isNull);
      // 額が分からなくても、賭けに直面していないことは分かる。
      expect(step.prompt.facingBet, isFalse);
    });

    test('リバーまで進み切ったらレビューできる', () {
      final input = base().copyWith(
        preflop: [
          _a(hero, PokerActionType.raise, 2.5),
          _a('BB', PokerActionType.call),
        ],
        flop: StreetInput(
          cards: PlayingCard.parseAll(['Ad', '7c', '2s']),
          actions: [
            _a('BB', PokerActionType.check),
            _a(hero, PokerActionType.check),
          ],
        ),
        turn: StreetInput(
          cards: PlayingCard.parseAll(['Kc']),
          actions: [
            _a('BB', PokerActionType.check),
            _a(hero, PokerActionType.check),
          ],
        ),
        river: StreetInput(
          cards: PlayingCard.parseAll(['9h']),
          actions: [
            _a('BB', PokerActionType.bet, 4),
            _a(hero, PokerActionType.call),
          ],
        ),
      );
      final flow = HandFlow(input);
      final step = flow.step as ReviewReady;
      expect(step.endedByFold, isFalse);
      expect(step.sawShowdown, isTrue);
      expect(flow.finalPotBb, 13.5);

      // ヒーローが直面した賭けが記録されている。
      // ブラインドを埋めるだけのプリフロップは、ポットオッズの対象にしない。
      expect(flow.heroFacedBets, hasLength(1));
      expect(flow.heroFacedBets.single.street, Street.river);
      expect(flow.heroFacedBets.single.toCallBb, 4);
      expect(flow.heroFacedBets.single.potBb, 9.5);
    });
  });
}
