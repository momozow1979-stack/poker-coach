import 'package:ai_poker_coach/shared/models/combo_counter.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StartingHand h(String code) => StartingHand.parse(code);
  PlayingCard c(String code) => PlayingCard.parse(code);

  group('ComboCounter.combos（ブロッカーなしの基本値）', () {
    test('ペアは6、スーテッドは4、オフスートは12', () {
      expect(ComboCounter.combos(h('AA')), 6);
      expect(ComboCounter.combos(h('AKs')), 4);
      expect(ComboCounter.combos(h('AKo')), 12);
    });
  });

  group('ComboCounter.combos（カード除外）', () {
    test('ペア: A が1枚見えていると 3 通り', () {
      expect(ComboCounter.combos(h('AA'), dead: [c('Ah')]), 3);
    });

    test('ペア: A が2枚見えていると 1 通り', () {
      expect(ComboCounter.combos(h('AA'), dead: [c('Ah'), c('As')]), 1);
    });

    test('スーテッド: そのスートの札が見えていると1つ減る', () {
      expect(ComboCounter.combos(h('AKs'), dead: [c('Ah')]), 3);
      // ハートのAとダイヤのKで2スートが潰れる。
      expect(ComboCounter.combos(h('AKs'), dead: [c('Ah'), c('Kd')]), 2);
    });

    test('オフスート: ブロッカーで正しく減る', () {
      // Ah が死ぬ → A残3, K残4, 生存スーテッド3 → 3*4-3 = 9
      expect(ComboCounter.combos(h('AKo'), dead: [c('Ah')]), 9);
      // 場に Kd → A残4, K残3, 生存スーテッド3 → 4*3-3 = 9
      expect(ComboCounter.combos(h('AKo'), dead: [c('Kd')]), 9);
    });
  });

  group('ComboCounter.totalCombos', () {
    test('複数ハンドの合計', () {
      expect(ComboCounter.totalCombos([h('AA'), h('KK')]), 12);
      // 場に Ac があると AA は 3 通りに減る（6+6 → 3+6 = 9）。
      expect(ComboCounter.totalCombos([h('AA'), h('KK')], dead: [c('Ac')]), 9);
    });
  });
}
