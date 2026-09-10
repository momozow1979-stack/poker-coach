import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

/// hero=AA, villain=72o、ボードは全員に無関係な低いカードにしておく。
/// 先頭2枚がヒーロー、次の2枚がヴィラン、残りがボード用に引かれる順。
PracticeDeck _deck() => PracticeDeck.ordered(
  PlayingCard.parseAll([
    'Ah', 'As', // hero
    '7c', '2d', // villain
    '3h', '4h', '5h', // flop
    '9c', // turn
    'Tc', // river
  ]),
);

void main() {
  group('配り始め', () {
    test('ヒーローが BTN・ヴィランが BB、ブラインドぶんポットに入っている', () {
      final engine = PracticeHandEngine(deck: _deck());
      final state = engine.state;

      expect(state.heroPosition.label, 'BTN');
      expect(state.villainPosition.label, 'BB');
      expect(state.pot, 1.5);
      expect(state.heroStack, 100);
      expect(state.villainStack, 99); // BB で 1bb 払い済み
      expect(state.actorToAct, Actor.hero);
      expect(state.street, Street.preflop);
    });
  });

  group('フォールドで終わる', () {
    test('ヴィランがオープンにフォールドすると、その場でヒーローの勝ち', () {
      final engine = PracticeHandEngine(deck: _deck());
      engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
      engine.apply(Actor.villain, PokerActionType.fold);

      final state = engine.state;
      expect(state.isOver, isTrue);
      expect(state.endedByFold, isTrue);
      expect(state.winner, Actor.hero);
      // デッドマネー 0.5(SB) + BB の 1 + ヒーローが上げた 2.5。
      expect(state.pot, 1.5 + 2.5);
      expect(state.actions.map((a) => a.action), [
        PokerActionType.raise,
        PokerActionType.fold,
      ]);
    });
  });

  group('ショーダウンまで進む', () {
    test('コール・チェックで進めると自動でボードが配られ、AA が勝つ', () {
      final engine = PracticeHandEngine(deck: _deck());

      engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
      engine.apply(Actor.villain, PokerActionType.call);
      expect(engine.state.street, Street.flop);
      expect(engine.state.board.map((c) => c.code), ['3h', '4h', '5h']);
      expect(engine.state.actorToAct, Actor.villain);

      engine.apply(Actor.villain, PokerActionType.check);
      engine.apply(Actor.hero, PokerActionType.check);
      expect(engine.state.street, Street.turn);
      expect(engine.state.board.length, 4);

      engine.apply(Actor.villain, PokerActionType.check);
      engine.apply(Actor.hero, PokerActionType.check);
      expect(engine.state.street, Street.river);
      expect(engine.state.board.length, 5);

      engine.apply(Actor.villain, PokerActionType.check);
      engine.apply(Actor.hero, PokerActionType.check);

      final state = engine.state;
      expect(state.isOver, isTrue);
      expect(state.sawShowdown, isTrue);
      expect(state.winner, Actor.hero); // AA vs 72o
      // デッドマネー 0.5(SB) + ヒーロー 2.5 + ヴィラン 2.5(BB の 1 込み)。
      expect(state.pot, 5.5);
    });
  });

  group('手番でない側が行動しようとするとエラー', () {
    test('プリフロップでいきなりヴィランを動かすと例外', () {
      final engine = PracticeHandEngine(deck: _deck());
      expect(
        () => engine.apply(Actor.villain, PokerActionType.call),
        throwsStateError,
      );
    });
  });

  group('選べる額のプリセット', () {
    test('プリフロップの最初はオープンサイズが並ぶ', () {
      final engine = PracticeHandEngine(deck: _deck());
      final choices = engine.state.choices!;
      expect(choices.facingBet, isTrue); // BB の 1bb に直面
      expect(choices.presetSizesBb, [2.2, 2.5, 3.0]);
    });
  });
}
