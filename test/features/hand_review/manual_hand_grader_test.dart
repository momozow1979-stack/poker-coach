import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/domain/manual_hand_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grade.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

const _grader = ManualHandGrader(ranges: MockRangeRepository());

HandAction _h(PokerActionType action, [double? size]) =>
    HandAction(actor: HandAction.heroActor, action: action, sizeBb: size);
HandAction _v(PokerActionType action, [double? size]) =>
    HandAction(actor: 'BB', action: action, sizeBb: size);

/// BTN でオープン → BB がコール → フロップで BB が [bet] BB 賭け、あなたが [response]。
HandReviewInput _btnVsBb({
  required List<String> hero,
  required List<String> flop,
  required double bet,
  required PokerActionType response,
}) => HandReviewInput(
  heroPosition: Position.btn,
  villainPosition: Position.bb,
  effectiveStackBb: 100,
  heroHand: PlayingCard.parseAll(hero),
  preflop: [_h(PokerActionType.raise, 2.5), _v(PokerActionType.call)],
  flop: StreetInput(
    cards: PlayingCard.parseAll(flop),
    actions: [_v(PokerActionType.bet, bet), _h(response)],
  ),
  turn: StreetInput(cards: PlayingCard.parseAll(const ['2c'])),
  river: StreetInput(cards: PlayingCard.parseAll(const ['3d'])),
);

void main() {
  group('プリフロップ（レンジ表で採点）', () {
    test('BTN の AA オープンは ○、72o オープンは ×', () {
      final aa = _grader.grade(
        HandReviewInput(
          heroHand: PlayingCard.parseAll(const ['Ah', 'As']),
          preflop: [_h(PokerActionType.raise, 2.5), _v(PokerActionType.fold)],
        ),
      );
      expect(aa.first.street, Street.preflop);
      expect(aa.first.verdict, PracticeVerdict.good);

      final junk = _grader.grade(
        HandReviewInput(
          heroHand: PlayingCard.parseAll(const ['7h', '2s']),
          preflop: [_h(PokerActionType.raise, 2.5), _v(PokerActionType.fold)],
        ),
      );
      expect(junk.first.verdict, PracticeVerdict.bad);
    });

    test('BB で BTN のオープンを受ける: AA のコールは ×（表は 3 ベット）', () {
      final grades = _grader.grade(
        HandReviewInput(
          heroPosition: Position.bb,
          villainPosition: Position.btn,
          heroHand: PlayingCard.parseAll(const ['Ah', 'As']),
          preflop: [
            const HandAction(
              actor: 'BTN',
              action: PokerActionType.raise,
              sizeBb: 2.5,
            ),
            _h(PokerActionType.call),
          ],
        ),
      );
      expect(grades.first.verdict, PracticeVerdict.bad);
      expect(grades.first.headline, contains('3ベット'));
    });

    test('表の無い組み合わせは採点しない（BB vs UTG）', () {
      final grades = _grader.grade(
        HandReviewInput(
          heroPosition: Position.bb,
          villainPosition: Position.utg,
          heroHand: PlayingCard.parseAll(const ['Ah', 'As']),
          preflop: [
            const HandAction(
              actor: 'UTG',
              action: PokerActionType.raise,
              sizeBb: 2.5,
            ),
            _h(PokerActionType.call),
          ],
        ),
      );
      expect(grades.first.verdict, isNull);
    });
  });

  group('フロップ以降で賭けに直面した判断（必要勝率と勝率で採点）', () {
    test('何も無い手で、大きなベットにコールするのは ×、降りるのは ○', () {
      ManualDecisionGrade flopOf(PokerActionType response) => _grader
          .grade(
            _btnVsBb(
              hero: const ['9h', '8h'],
              flop: const ['As', 'Kd', '4c'],
              bet: 5.5,
              response: response,
            ),
          )
          .firstWhere((g) => g.street == Street.flop);
      final call = flopOf(PokerActionType.call);
      expect(call.verdict, PracticeVerdict.bad);
      expect(call.numbers.map((n) => n.$1), contains('必要勝率（ポットオッズ）'));
      expect(flopOf(PokerActionType.fold).verdict, PracticeVerdict.good);
    });

    test('セットで受けるのは ○', () {
      final grade = _grader
          .grade(
            _btnVsBb(
              hero: const ['4h', '4s'],
              flop: const ['As', 'Kd', '4c'],
              bet: 3,
              response: PokerActionType.call,
            ),
          )
          .firstWhere((g) => g.street == Street.flop);
      expect(grade.verdict, PracticeVerdict.good);
    });

    test('自分から賭けた判断は採点せず、必要な降りる割合だけ示す', () {
      final grades = _grader.grade(
        HandReviewInput(
          heroHand: PlayingCard.parseAll(const ['9h', '8h']),
          preflop: [_h(PokerActionType.raise, 2.5), _v(PokerActionType.call)],
          flop: StreetInput(
            cards: PlayingCard.parseAll(const ['As', 'Kd', '4c']),
            actions: [
              _v(PokerActionType.check),
              _h(PokerActionType.bet, 2.75),
              _v(PokerActionType.fold),
            ],
          ),
        ),
      );
      final bet = grades.firstWhere((g) => g.street == Street.flop);
      expect(bet.verdict, isNull);
      // 2.75 ÷ (5.5 + 2.75) = 33%
      expect(bet.numbers.single.$2, '33%');
    });
  });
}
