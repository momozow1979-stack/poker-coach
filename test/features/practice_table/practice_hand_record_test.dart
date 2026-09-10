import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_record.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('イベント列が JSON を往復しても再現できる', () {
    final engine = PracticeHandEngine(
      deck: PracticeDeck.ordered(
        PlayingCard.parseAll(['Ah', 'As', '7c', '2d', '3h', '4h', '5h']),
      ),
    );
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    engine.apply(Actor.villain, PokerActionType.fold);

    final record = PracticeHandRecord(
      id: 'test-1',
      createdAt: DateTime.utc(2026, 1, 1),
      events: engine.events,
      endedByFold: true,
      winner: Actor.hero,
      finalPotBb: engine.state.pot,
    );

    final restored = PracticeHandRecord.fromJson(record.toJson());

    expect(restored.id, record.id);
    expect(restored.winner, Actor.hero);
    expect(restored.endedByFold, isTrue);
    expect(restored.finalPotBb, record.finalPotBb);
    expect(restored.events.length, engine.events.length);
  });
}
