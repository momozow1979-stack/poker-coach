import 'playing_card.dart';

/// 5〜7 枚から役の強さを 1 つの整数にする、[HandStrength.best] の高速版。
///
/// [HandStrength.best] は 5 枚の組を総当たりしながら毎回リストやマップを
/// 作るため、「相手の手札の候補すべて × 残りのボードすべて」を数え上げる
/// 勝率計算（数十万回の判定）には遅すぎる。ここでは割り当てを伴わない
/// ビット演算だけで判定する。
///
/// 返す値の大小関係は [HandStrength.best] の `compareTo` と完全に一致する
/// （`test/shared/fast_hand_evaluator_test.dart` で大量のランダムな手を照合）。
/// 値そのものに意味はなく、比較にだけ使う。
abstract final class FastHandEvaluator {
  /// カードを 0〜51 の番号にする。`ランク(2=0 … A=12) * 4 + スート`。
  static int indexOf(PlayingCard card) =>
      (card.rank.strength - 2) * 4 + card.suit.index;

  static const _straightFlush = 8;
  static const _quads = 7;
  static const _fullHouse = 6;
  static const _flush = 5;
  static const _straight = 4;
  static const _trips = 3;
  static const _twoPair = 2;
  static const _onePair = 1;
  static const _highCard = 0;

  // 判定のたびにリストを作らないよう使い回す作業領域（Dart は 1 つの
  // isolate 内では同時に 2 つの判定が走らないので共有してよい）。
  static final List<int> _rankCounts = List<int>.filled(13, 0);
  static final List<int> _suitMasks = List<int>.filled(4, 0);
  static final List<int> _suitCounts = List<int>.filled(4, 0);

  /// [cards] は [indexOf] の番号で 5〜7 枚。大きいほど強い。
  static int score(List<int> cards) {
    final rankCounts = _rankCounts..fillRange(0, 13, 0);
    final suitMasks = _suitMasks..fillRange(0, 4, 0);
    final suitCounts = _suitCounts..fillRange(0, 4, 0);
    var rankMask = 0;
    for (final card in cards) {
      final rank = card >> 2;
      final suit = card & 3;
      rankCounts[rank]++;
      suitMasks[suit] |= 1 << rank;
      suitCounts[suit]++;
      rankMask |= 1 << rank;
    }

    var flushMask = 0;
    for (var suit = 0; suit < 4; suit++) {
      if (suitCounts[suit] >= 5) flushMask = suitMasks[suit];
    }
    if (flushMask != 0) {
      final high = _straightHigh(flushMask);
      if (high >= 0) return _pack(_straightFlush, [high]);
    }

    var quad = -1;
    var tripsHigh = -1;
    var tripsLow = -1;
    var pairHigh = -1;
    var pairLow = -1;
    for (var rank = 12; rank >= 0; rank--) {
      final count = rankCounts[rank];
      if (count == 4) {
        quad = rank;
      } else if (count == 3) {
        if (tripsHigh < 0) {
          tripsHigh = rank;
        } else if (tripsLow < 0) {
          tripsLow = rank;
        }
      } else if (count == 2) {
        if (pairHigh < 0) {
          pairHigh = rank;
        } else if (pairLow < 0) {
          pairLow = rank;
        }
      }
    }

    if (quad >= 0) {
      return _pack(_quads, [quad, _highest(rankMask & ~(1 << quad), 1)[0]]);
    }
    if (tripsHigh >= 0) {
      // 2 組目のスリーカードも、フルハウスのペア部分として使える。
      final pairPart = tripsLow > pairHigh ? tripsLow : pairHigh;
      if (pairPart >= 0) return _pack(_fullHouse, [tripsHigh, pairPart]);
    }
    if (flushMask != 0) return _pack(_flush, _highest(flushMask, 5));

    final straightHigh = _straightHigh(rankMask);
    if (straightHigh >= 0) return _pack(_straight, [straightHigh]);

    if (tripsHigh >= 0) {
      final kickers = _highest(rankMask & ~(1 << tripsHigh), 2);
      return _pack(_trips, [tripsHigh, ...kickers]);
    }
    if (pairHigh >= 0 && pairLow >= 0) {
      final rest = rankMask & ~(1 << pairHigh) & ~(1 << pairLow);
      return _pack(_twoPair, [pairHigh, pairLow, _highest(rest, 1)[0]]);
    }
    if (pairHigh >= 0) {
      final kickers = _highest(rankMask & ~(1 << pairHigh), 3);
      return _pack(_onePair, [pairHigh, ...kickers]);
    }
    return _pack(_highCard, _highest(rankMask, 5));
  }

  /// 役の種類を `[HandCategory.power]` と同じ 0〜8 で取り出す。
  static int categoryOf(int score) => score >> 20;

  /// ストレートの最上位ランク。無ければ -1。A-2-3-4-5 は 5（番号 3）。
  static int _straightHigh(int mask) {
    for (var high = 12; high >= 4; high--) {
      final run = 0x1F << (high - 4);
      if (mask & run == run) return high;
    }
    const wheel = (1 << 12) | 0xF; // A, 2, 3, 4, 5
    if (mask & wheel == wheel) return 3;
    return -1;
  }

  /// [mask] のうち上位 [count] 個のランク（強い順）。
  static List<int> _highest(int mask, int count) {
    final result = <int>[];
    for (var rank = 12; rank >= 0 && result.length < count; rank--) {
      if (mask & (1 << rank) != 0) result.add(rank);
    }
    return result;
  }

  /// 役の種類を上位に、同じ役同士の比較材料を下位に詰める。
  /// ランクは 0〜12 なので 4 ビットずつで足り、最大 24 ビットに収まる
  /// （Web の JavaScript でも整数のまま扱える範囲）。
  static int _pack(int category, List<int> ranks) {
    var value = category;
    for (var i = 0; i < 5; i++) {
      value = (value << 4) | (i < ranks.length ? ranks[i] : 0);
    }
    return value;
  }
}
