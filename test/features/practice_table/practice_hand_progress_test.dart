import 'dart:math';

import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

/// 画面に出る選択肢だけを使って、いろいろな打ち方で多数のハンドを最後まで
/// 進め、途中で止まらない（同じやり取りが繰り返されない）ことを確かめる。
///
/// 以前、チップが少なくなった場面で「すでに場に出ている額より小さいレイズ」が
/// 出て、揃える額が変わらないまま同じやり取りが続く不具合があった。
void main() {
  for (final style in PracticeOpponentStyle.values) {
    test('画面の選択肢だけで打てば、どのハンドも有限の手数で終わる（相手: ${style.label}）', () {
      _playMany(SimplePracticeOpponent(style: style), hands: 600);
    });
  }
}

void _playMany(PracticeOpponent opponent, {required int hands}) {
  {
    final rng = Random(7);
    for (var hand = 0; hand < hands; hand++) {
      final engine = PracticeHandEngine(deck: PracticeDeck(Random(hand)));
      var steps = 0;
      while (!engine.state.isOver) {
        steps++;
        expect(steps, lessThan(80), reason: 'hand $hand が終わらない');
        final state = engine.state;
        final choices = state.choices!;
        // 選択肢の額は、手元のチップで出せる範囲・揃える額より上に限る。
        for (final size in choices.presetSizesBb) {
          expect(size, greaterThan(state.currentBetBb));
        }
        if (state.actorToAct == Actor.villain) {
          final decision = opponent.decide(state);
          expect(choices.choices, contains(decision.action));
          engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
          continue;
        }
        final roll = rng.nextDouble();
        final sizes = choices.presetSizesBb;
        if (choices.choices.contains(PokerActionType.raise) &&
            (state.street == Street.preflop || roll < 0.3)) {
          engine.apply(
            Actor.hero,
            PokerActionType.raise,
            sizeBb: sizes[rng.nextInt(sizes.length)],
          );
        } else if (choices.choices.contains(PokerActionType.bet) &&
            roll < 0.5) {
          engine.apply(
            Actor.hero,
            PokerActionType.bet,
            sizeBb: sizes[rng.nextInt(sizes.length)],
          );
        } else if (roll < 0.05 &&
            choices.choices.contains(PokerActionType.allIn)) {
          engine.apply(Actor.hero, PokerActionType.allIn);
        } else {
          engine.apply(
            Actor.hero,
            choices.facingBet ? PokerActionType.call : PokerActionType.check,
          );
        }
      }
    }
  }
}
