import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const opponent = SimplePracticeOpponent();

  test('プリフロップ: ヴィランが AA なら 3bet を選ぶ', () {
    final engine = PracticeHandEngine(
      deck: PracticeDeck.ordered(
        PlayingCard.parseAll(['7c', '2d', 'Ah', 'As', '3h', '4h', '9c', 'Tc']),
      ),
    );
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    final decision = opponent.decide(engine.state);
    expect(decision.action, PokerActionType.raise);
    expect(decision.sizeBb, greaterThan(2.5));
  });

  test('プリフロップ: ヴィランが 72o ならフォールドを選ぶ', () {
    final engine = PracticeHandEngine(
      deck: PracticeDeck.ordered(
        PlayingCard.parseAll(['Ah', 'As', '7c', '2d', '3h', '4h', '9c', 'Tc']),
      ),
    );
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    final decision = opponent.decide(engine.state);
    expect(decision.action, PokerActionType.fold);
  });

  test('ヴィランの番でないときに呼ぶと例外', () {
    final engine = PracticeHandEngine(
      deck: PracticeDeck.ordered(
        PlayingCard.parseAll(['Ah', 'As', '7c', '2d', '3h', '4h', '9c', 'Tc']),
      ),
    );
    expect(() => opponent.decide(engine.state), throwsStateError);
  });
}
