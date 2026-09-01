import 'package:ai_poker_coach/shared/models/hand_strength.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

HandStrength best(String cards) =>
    HandStrength.best(PlayingCard.parseAll(cards.split(' ')));

void main() {
  group('役の判定', () {
    test('それぞれの役を正しく見分ける', () {
      expect(best('Ah Kh Qh Jh Th').category, HandCategory.straightFlush);
      expect(best('9c 9d 9h 9s 2c').category, HandCategory.quads);
      expect(best('9c 9d 9h 2s 2c').category, HandCategory.fullHouse);
      expect(best('Ah 9h 7h 4h 2h').category, HandCategory.flush);
      expect(best('9c 8d 7h 6s 5c').category, HandCategory.straight);
      expect(best('9c 9d 9h 4s 2c').category, HandCategory.trips);
      expect(best('9c 9d 4h 4s 2c').category, HandCategory.twoPair);
      expect(best('9c 9d 7h 4s 2c').category, HandCategory.onePair);
      expect(best('Ac 9d 7h 4s 2c').category, HandCategory.highCard);
    });

    test('A-2-3-4-5 のストレートを認識し、5 が最上位になる', () {
      final wheel = best('Ac 2d 3h 4s 5c');
      expect(wheel.category, HandCategory.straight);
      expect(wheel.tiebreakers.first, 5);
      // 6 までのストレートのほうが強い。
      expect(wheel.compareTo(best('2d 3h 4s 5c 6d')), lessThan(0));
    });

    test('7枚から一番強い5枚を選ぶ', () {
      // ボード A K Q J T にどんな2枚を足してもストレート。
      expect(best('2c 3d Ah Kh Qs Jc Td').category, HandCategory.straight);
      // セットとフラッシュが両方あるときはフラッシュを取る（♥ が5枚）。
      expect(best('9h 9d 9s 2h 5h 7h Kh').category, HandCategory.flush);
    });

    test('同じ役はキッカーで比べる', () {
      expect(
        best('Ac Ad Kh 7s 2c').compareTo(best('Ac Ad Qh 7s 2c')),
        greaterThan(0),
      );
      expect(best('Ac Ad Kh 7s 2c').compareTo(best('Ah As Kd 7c 2d')), 0);
    });

    test('フラッシュ同士は上のカードで決まる', () {
      expect(
        best('Ah 9h 7h 4h 2h').compareTo(best('Kh 9h 7h 4h 3h')),
        greaterThan(0),
      );
    });
  });
}
