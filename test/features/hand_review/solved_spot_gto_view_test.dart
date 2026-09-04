import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/domain/solved_spot.dart';
import 'package:ai_poker_coach/features/hand_review/infrastructure/in_memory_solved_spot_repository.dart';
import 'package:ai_poker_coach/features/hand_review/infrastructure/mock_hand_review_repository.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// `MockHandReviewRepository` は「実際に学習済みのスポットに一致したときだけ
/// 実数値を出し、一致しないときは今までどおり数値を出さない」を守る必要が
/// ある。捏造防止の要である安全策そのものをここで固定する。
void main() {
  const board7h2d3s = ['7h', '2d', '3s'];

  HandReviewInput inputOn(List<String> board, List<String> heroHand) =>
      HandReviewInput(
        heroPosition: Position.btn,
        villainPosition: Position.bb,
        effectiveStackBb: 100,
        heroHand: PlayingCard.parseAll(heroHand),
        preflop: [
          HandAction(actor: HandAction.heroActor, action: PokerActionType.raise, sizeBb: 2.5),
          HandAction(actor: 'BB', action: PokerActionType.call),
        ],
        flop: StreetInput(cards: PlayingCard.parseAll(board)),
      );

  group('一致するスポットが無いとき', () {
    const repository = MockHandReviewRepository(
      MockRangeRepository(),
      InMemorySolvedSpotRepository(),
    );

    test('従来どおり「数値を示さない」安全策の文言が出る', () {
      final result = repository.analyze(inputOn(board7h2d3s, ['Ah', 'Ac']));
      expect(result.gtoView, contains('正確なソルバーの頻度は入力から求まらない'));
      expect(result.gtoView, isNot(contains('%')));
    });
  });

  group('一致するスポットがあるとき', () {
    final solvedRepository = InMemorySolvedSpotRepository([
      SolvedSpot(
        id: 'test_spot',
        boardFlop: PlayingCard.parseAll(board7h2d3s),
        heroRangeNotation: 'AA',
        villainRangeNotation: 'KK',
        iterationsTrained: 1000000,
        measuredExactExploitability: 0.033,
        entries: [
          SolvedSpotEntry(
            heroCombo: PlayingCard.parseAll(const ['Ah', 'Ac']),
            strategy: const {'x': 0.3, 'b': 0.7},
          ),
        ],
      ),
    ]);
    final repository = MockHandReviewRepository(
      const MockRangeRepository(),
      solvedRepository,
    );

    test('実測値そのものの頻度が本文に出る（捏造でも近似でもない）', () {
      final result = repository.analyze(inputOn(board7h2d3s, ['Ah', 'Ac']));
      expect(result.gtoView, contains('チェック30%'));
      expect(result.gtoView, contains('ベット70%'));
      expect(result.gtoView, contains('KK'));
      expect(result.gtoView, contains('1000000'));
      expect(result.gtoView, contains('0.033'));
      expect(result.gtoView, isNot(contains('正確なソルバーの頻度は入力から求まらない')));
    });

    test('ボードが違えば一致せず、安全策のままになる', () {
      final result = repository.analyze(
        inputOn(const ['Kd', '9c', '4s'], const ['Ah', 'Ac']),
      );
      expect(result.gtoView, contains('正確なソルバーの頻度は入力から求まらない'));
    });

    test('ヒーローの手が違えば一致せず、安全策のままになる', () {
      final result = repository.analyze(inputOn(board7h2d3s, const ['Kh', 'Kc']));
      expect(result.gtoView, contains('正確なソルバーの頻度は入力から求まらない'));
    });
  });
}
