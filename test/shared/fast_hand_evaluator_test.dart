import 'dart:math';

import 'package:ai_poker_coach/shared/models/fast_hand_evaluator.dart';
import 'package:ai_poker_coach/shared/models/hand_strength.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> _cards(String spaced) =>
    spaced.split(' ').map(PlayingCard.parse).toList();

int _fast(List<PlayingCard> cards) =>
    FastHandEvaluator.score(cards.map(FastHandEvaluator.indexOf).toList());

void main() {
  group('FastHandEvaluator', () {
    test('役の種類が HandStrength と一致する（代表的な形）', () {
      const cases = {
        'Ah Kh Qh Jh Th 2c 3d': HandCategory.straightFlush,
        'Ah 2h 3h 4h 5h Kc Kd': HandCategory.straightFlush,
        '9s 9h 9d 9c 2h 3d 4c': HandCategory.quads,
        'Ks Kh Kd 2c 2h 2d 7c': HandCategory.fullHouse,
        'Ks Kh Kd 7c 7h 2d 3c': HandCategory.fullHouse,
        '2h 7h 9h Jh Kh Ac Ad': HandCategory.flush,
        'As 2d 3c 4h 5s Kd Kc': HandCategory.straight,
        'Ts Jd Qc Kh As 2d 2c': HandCategory.straight,
        '7s 7h 7d Ac Kh 2d 4c': HandCategory.trips,
        'Ks Kh 7d 7c 2h 2d Ac': HandCategory.twoPair,
        'Ks Kh 7d 8c 2h 3d Ac': HandCategory.onePair,
        'Ks Qh 7d 8c 2h 3d 5c': HandCategory.highCard,
      };
      for (final entry in cases.entries) {
        final cards = _cards(entry.key);
        expect(
          FastHandEvaluator.categoryOf(_fast(cards)),
          HandStrength.best(cards).category.power,
          reason: entry.key,
        );
      }
    });

    test('ランダムな手同士の大小が HandStrength と完全に一致する', () {
      final random = Random(20261120);
      final deck = PlayingCard.fullDeck;
      for (var i = 0; i < 4000; i++) {
        final shuffled = [...deck]..shuffle(random);
        // 5〜7 枚を混ぜて検査する（フロップ・ターン・リバー相当）。
        final size = 5 + i % 3;
        final board = shuffled.sublist(0, size - 2);
        final a = [...shuffled.sublist(size - 2, size), ...board];
        final b = [...shuffled.sublist(size, size + 2), ...board];
        final expected = HandStrength.best(a).compareTo(HandStrength.best(b));
        final actual = _fast(a).compareTo(_fast(b));
        expect(actual.sign, expected.sign, reason: '$a vs $b');
      }
    });
  });
}
