import 'playing_card.dart';

/// 役の種類。強い順に大きい [power] を持つ。
enum HandCategory {
  highCard('ハイカード', 0),
  onePair('ワンペア', 1),
  twoPair('ツーペア', 2),
  trips('スリーカード', 3),
  straight('ストレート', 4),
  flush('フラッシュ', 5),
  fullHouse('フルハウス', 6),
  quads('フォーカード', 7),
  straightFlush('ストレートフラッシュ', 8);

  const HandCategory(this.label, this.power);

  final String label;
  final int power;
}

/// 5 枚で作った役の強さ。同じ役同士は [tiebreakers] を上から比べる。
class HandStrength implements Comparable<HandStrength> {
  const HandStrength(this.category, this.tiebreakers, this.cards);

  final HandCategory category;

  /// 同じ役同士を比べるための数値列。強い順に並ぶ。
  final List<int> tiebreakers;

  /// 役を作っている 5 枚。
  final List<PlayingCard> cards;

  @override
  int compareTo(HandStrength other) {
    final byCategory = category.power.compareTo(other.category.power);
    if (byCategory != 0) return byCategory;
    for (var i = 0; i < tiebreakers.length; i++) {
      if (i >= other.tiebreakers.length) break;
      final diff = tiebreakers[i].compareTo(other.tiebreakers[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// 5〜7 枚から一番強い 5 枚を選ぶ。
  static HandStrength best(List<PlayingCard> cards) {
    if (cards.length < 5) {
      throw ArgumentError('役の判定には5枚以上必要です: ${cards.length}枚');
    }
    if (cards.length == 5) return _evaluate5(cards);

    HandStrength? best;
    final n = cards.length;
    for (var a = 0; a < n - 4; a++) {
      for (var b = a + 1; b < n - 3; b++) {
        for (var c = b + 1; c < n - 2; c++) {
          for (var d = c + 1; d < n - 1; d++) {
            for (var e = d + 1; e < n; e++) {
              final hand = _evaluate5([
                cards[a],
                cards[b],
                cards[c],
                cards[d],
                cards[e],
              ]);
              if (best == null || hand.compareTo(best) > 0) best = hand;
            }
          }
        }
      }
    }
    return best!;
  }

  static HandStrength _evaluate5(List<PlayingCard> hand) {
    final strengths = hand.map((card) => card.rank.strength).toList()
      ..sort((a, b) => b.compareTo(a));

    final bySuit = <CardSuit, int>{};
    for (final card in hand) {
      bySuit.update(card.suit, (count) => count + 1, ifAbsent: () => 1);
    }
    final isFlush = bySuit.values.any((count) => count == 5);

    final straightHigh = _straightHigh(strengths);

    if (isFlush && straightHigh != null) {
      return HandStrength(HandCategory.straightFlush, [straightHigh], hand);
    }

    final byRank = <int, int>{};
    for (final strength in strengths) {
      byRank.update(strength, (count) => count + 1, ifAbsent: () => 1);
    }
    // 枚数の多い順、同数ならランクの高い順。
    final groups = byRank.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : b.key.compareTo(a.key);
      });
    final counts = groups.map((entry) => entry.value).toList();
    final ranks = groups.map((entry) => entry.key).toList();

    if (counts.first == 4) {
      return HandStrength(HandCategory.quads, ranks, hand);
    }
    if (counts.first == 3 && counts.length > 1 && counts[1] == 2) {
      return HandStrength(HandCategory.fullHouse, ranks, hand);
    }
    if (isFlush) return HandStrength(HandCategory.flush, strengths, hand);
    if (straightHigh != null) {
      return HandStrength(HandCategory.straight, [straightHigh], hand);
    }
    if (counts.first == 3) {
      return HandStrength(HandCategory.trips, ranks, hand);
    }
    if (counts.first == 2 && counts.length > 1 && counts[1] == 2) {
      return HandStrength(HandCategory.twoPair, ranks, hand);
    }
    if (counts.first == 2) {
      return HandStrength(HandCategory.onePair, ranks, hand);
    }
    return HandStrength(HandCategory.highCard, strengths, hand);
  }

  /// ストレートの一番上のランク。無ければ null。
  ///
  /// A-2-3-4-5 は 5 が最上位として扱う。
  static int? _straightHigh(List<int> descending) {
    final unique = descending.toSet().toList()..sort((a, b) => b.compareTo(a));
    if (unique.length < 5) return null;
    for (var i = 0; i + 4 < unique.length; i++) {
      if (unique[i] - unique[i + 4] == 4) return unique[i];
    }
    // ホイール（A を 1 として扱う）。
    const wheel = [14, 5, 4, 3, 2];
    if (wheel.every(unique.contains)) return 5;
    return null;
  }
}
