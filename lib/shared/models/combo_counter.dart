import 'playing_card.dart';
import 'starting_hand.dart';

/// スターティングハンド（169分類）が実際に何通りの組み合わせ（コンボ）に
/// なるかを数える。場や自分の手札で見えているカードは除外（ブロッカー）できる。
///
/// これは「計算で確定する」数（ポットオッズやアウツと同じく AGENTS.md ルール1で
/// 許される種類）であり、ソルバーの頻度・EV のような捏造ではない。
/// 解説で「バリューが約X通り・ブラフが約Y通り」と具体的に語るための土台。
abstract final class ComboCounter {
  /// あるランクのうち、まだデッキに残っている枚数（0〜4）。
  static int _availableOfRank(CardRank rank, Set<PlayingCard> dead) =>
      4 -
      CardSuit.values
          .where((suit) => dead.contains(PlayingCard(rank, suit)))
          .length;

  /// [hand] のスーテッド組で、両方のランクが残っているスートの数（0〜4）。
  static int _availableSuited(StartingHand hand, Set<PlayingCard> dead) =>
      CardSuit.values
          .where(
            (suit) =>
                !dead.contains(PlayingCard(hand.high, suit)) &&
                !dead.contains(PlayingCard(hand.low, suit)),
          )
          .length;

  /// [hand] の残りコンボ数。[dead] は場・自分の手札など、除外する札。
  ///
  /// ブロッカーなしの基本値はペア6 / スーテッド4 / オフスート12。
  static int combos(
    StartingHand hand, {
    Iterable<PlayingCard> dead = const [],
  }) {
    final deadSet = dead.toSet();
    switch (hand.shape) {
      case HandShape.pair:
        final n = _availableOfRank(hand.high, deadSet);
        return n * (n - 1) ~/ 2; // C(n, 2)
      case HandShape.suited:
        return _availableSuited(hand, deadSet);
      case HandShape.offsuit:
        final highN = _availableOfRank(hand.high, deadSet);
        final lowN = _availableOfRank(hand.low, deadSet);
        // 高低の掛け合わせから、同じスート（＝スーテッド）になる分を引く。
        return highN * lowN - _availableSuited(hand, deadSet);
    }
  }

  /// 複数ハンドの合計コンボ数。
  static int totalCombos(
    Iterable<StartingHand> hands, {
    Iterable<PlayingCard> dead = const [],
  }) {
    final deadSet = dead.toSet();
    var total = 0;
    for (final hand in hands) {
      total += combos(hand, dead: deadSet);
    }
    return total;
  }
}
