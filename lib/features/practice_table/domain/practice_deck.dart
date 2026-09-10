import 'dart:math';

import '../../../shared/models/playing_card.dart';

/// 練習用のカード配布。
///
/// [Random] を外から渡せるようにしてあるのはテストのため
/// （シードを固定すれば同じ配布を再現できる）。
class PracticeDeck {
  PracticeDeck([Random? random]) : _random = random ?? Random() {
    _remaining = List.of(PlayingCard.fullDeck)..shuffle(_random);
  }

  /// 山札の中身と順序を固定して作る。テストで特定のハンドを再現するため
  /// だけに使う（[cards] の先頭から順に配られる）。
  PracticeDeck.ordered(List<PlayingCard> cards)
    : _random = Random(0),
      _remaining = List.of(cards);

  final Random _random;
  late final List<PlayingCard> _remaining;

  /// 山札の先頭から [count] 枚を引いて取り除く。
  List<PlayingCard> draw(int count) {
    if (count > _remaining.length) {
      throw StateError('山札が足りません（残り${_remaining.length}枚、$count枚要求）');
    }
    final cards = _remaining.sublist(0, count);
    _remaining.removeRange(0, count);
    return cards;
  }
}
