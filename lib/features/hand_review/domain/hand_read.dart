import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/playing_card.dart';

/// ある時点でのヒーローの手を、言葉で説明できる形にしたもの。
///
/// ここに入る値はすべてカードから確定するもので、推測は含まない。
class HandRead {
  const HandRead({
    required this.strength,
    required this.label,
    required this.draws,
    required this.improvingCards,
  });

  final HandStrength strength;

  /// 「A のトップペア（キッカー Q）」のような呼び名。
  final String label;

  /// 「フラッシュドロー（あと1枚）」のようなドローの説明。
  final List<String> draws;

  /// あと1枚でストレート以上になるカードの枚数。
  ///
  /// 残りのデッキを実際に数えているので、目安ではなく正確な枚数。
  final int improvingCards;

  bool get hasDraw => draws.isNotEmpty;

  /// フロップとターンでのみ意味を持つ。
  static HandRead of(List<PlayingCard> hole, List<PlayingCard> board) {
    final all = [...hole, ...board];
    final strength = HandStrength.best(all);
    return HandRead(
      strength: strength,
      label: _label(strength, hole, board),
      draws: _draws(hole, board),
      improvingCards: board.length >= 5 ? 0 : _countImproving(hole, board),
    );
  }

  // -------------------------------------------------------------- 呼び名 ----

  static String _label(
    HandStrength strength,
    List<PlayingCard> hole,
    List<PlayingCard> board,
  ) {
    final boardRanks = board.map((card) => card.rank.strength).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    switch (strength.category) {
      case HandCategory.highCard:
        final high = hole
            .map((card) => card.rank)
            .reduce((a, b) => a.strength >= b.strength ? a : b);
        return '${high.symbol}ハイ（まだ何も出来ていない）';
      case HandCategory.onePair:
        return _pairLabel(strength, hole, boardRanks);
      case HandCategory.twoPair:
        final top = _symbolOf(strength.tiebreakers[0]);
        final second = _symbolOf(strength.tiebreakers[1]);
        return '$top と $second のツーペア';
      case HandCategory.trips:
        final rank = _symbolOf(strength.tiebreakers[0]);
        final inHole = hole
            .where((card) => card.rank.strength == strength.tiebreakers[0])
            .length;
        // 手札2枚が絡むセットは、相手から見えにくいぶん強く扱える。
        return inHole >= 2 ? '$rank のセット' : '$rank のスリーカード';
      case HandCategory.straight:
        return '${_symbolOf(strength.tiebreakers[0])} までのストレート';
      case HandCategory.flush:
        return '${_symbolOf(strength.tiebreakers[0])} ハイのフラッシュ';
      case HandCategory.fullHouse:
        final three = _symbolOf(strength.tiebreakers[0]);
        final pair = _symbolOf(strength.tiebreakers[1]);
        return '$three が3枚、$pair が2枚のフルハウス';
      case HandCategory.quads:
        return '${_symbolOf(strength.tiebreakers[0])} のフォーカード';
      case HandCategory.straightFlush:
        return '${_symbolOf(strength.tiebreakers[0])} までのストレートフラッシュ';
    }
  }

  static String _pairLabel(
    HandStrength strength,
    List<PlayingCard> hole,
    List<int> boardRanks,
  ) {
    final paired = strength.tiebreakers[0];
    final symbol = _symbolOf(paired);
    final isPocketPair =
        hole.length == 2 && hole[0].rank.strength == hole[1].rank.strength;

    final String position;
    if (isPocketPair && hole[0].rank.strength == paired) {
      position = boardRanks.isEmpty || paired > boardRanks.first
          ? 'オーバーペア'
          : 'アンダーペア';
    } else {
      final index = boardRanks.indexOf(paired);
      position = switch (index) {
        0 => 'トップペア',
        1 => 'セカンドペア',
        2 => 'サードペア',
        _ => index < 0 ? 'ペア' : '下位のペア',
      };
    }

    final kicker = _kickerOf(strength, paired, hole);
    return kicker == null
        ? '$symbol の$position'
        : '$symbol の$position（キッカー $kicker）';
  }

  /// キッカーは自分の手札から取る。
  ///
  /// 役だけで決めると、ボードに乗っている札をキッカーとして出してしまう。
  /// 「キッカー K」と言われた人は自分が K を持っていると読むので、
  /// 差がつくのは自分の2枚目だけ、という前提に合わせる。
  static String? _kickerOf(
    HandStrength strength,
    int pairedRank,
    List<PlayingCard> hole,
  ) {
    final playing = strength.cards.toSet();
    final candidates = [
      for (final card in hole)
        if (card.rank.strength != pairedRank && playing.contains(card))
          card.rank.strength,
    ]..sort((a, b) => b.compareTo(a));
    return candidates.isEmpty ? null : _symbolOf(candidates.first);
  }

  static String _symbolOf(int strength) =>
      CardRank.values.firstWhere((rank) => rank.strength == strength).symbol;

  // -------------------------------------------------------------- ドロー ----

  static List<String> _draws(List<PlayingCard> hole, List<PlayingCard> board) {
    if (board.length >= 5) return const [];
    final all = [...hole, ...board];
    final draws = <String>[];

    final bySuit = <CardSuit, int>{};
    for (final card in all) {
      bySuit.update(card.suit, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in bySuit.entries) {
      final holeCount = hole.where((card) => card.suit == entry.key).length;
      if (holeCount == 0) continue;
      if (entry.value == 4) {
        draws.add('${entry.key.symbol} のフラッシュドロー（あと1枚）');
      } else if (entry.value == 3 && board.length == 3) {
        draws.add('${entry.key.symbol} のバックドアフラッシュ（あと2枚）');
      }
    }

    final straightOuts = _straightOuts(hole, board);
    if (straightOuts >= 8) {
      draws.add('両側が伸びるストレートドロー（$straightOuts枚）');
    } else if (straightOuts > 0) {
      draws.add('片側だけのストレートドロー（$straightOuts枚）');
    }

    return draws;
  }

  /// あと1枚でストレートになるランクの数（枚数ではなくランク数×4ではない）。
  ///
  /// 実際に残っているカードを数えるので、ボードに出ているぶんは除かれる。
  static int _straightOuts(List<PlayingCard> hole, List<PlayingCard> board) {
    final used = {...hole, ...board};
    final current = HandStrength.best([...hole, ...board]).category;
    if (current.power >= HandCategory.straight.power) return 0;

    var count = 0;
    for (final card in PlayingCard.fullDeck) {
      if (used.contains(card)) continue;
      final next = HandStrength.best([...hole, ...board, card]);
      if (next.category == HandCategory.straight ||
          next.category == HandCategory.straightFlush) {
        count++;
      }
    }
    return count;
  }

  /// あと1枚でストレート以上になるカードの枚数。
  static int _countImproving(List<PlayingCard> hole, List<PlayingCard> board) {
    if (board.length < 3) return 0;
    final used = {...hole, ...board};
    final current = HandStrength.best([...hole, ...board]);
    if (current.category.power >= HandCategory.straight.power) return 0;

    var count = 0;
    for (final card in PlayingCard.fullDeck) {
      if (used.contains(card)) continue;
      final next = HandStrength.best([...hole, ...board, card]);
      if (next.category.power >= HandCategory.straight.power) count++;
    }
    return count;
  }
}

/// 2 人の手札が分かっているときの、その時点での正確な勝率。
///
/// 残りのカードを全数列挙して数えるので、見積もりではなく確定値。
class ExactEquity {
  const ExactEquity({required this.win, required this.tie, required this.lose});

  final int win;
  final int tie;
  final int lose;

  int get total => win + tie + lose;

  /// 引き分けを半分として数えた勝率（0.0〜1.0）。
  double get value => total == 0 ? 0 : (win + tie / 2) / total;

  int get percent => (value * 100).round();

  /// フロップ以降でのみ計算する。
  ///
  /// プリフロップは組み合わせが多すぎて端末で回すには重いため、
  /// 出せないときは null を返す（概算を出して数字を装うことはしない）。
  static ExactEquity? between({
    required List<PlayingCard> hero,
    required List<PlayingCard> villain,
    required List<PlayingCard> board,
  }) {
    if (hero.length != 2 || villain.length != 2) return null;
    if (board.length < 3 || board.length > 5) return null;

    final used = {...hero, ...villain, ...board};
    final deck = [
      for (final card in PlayingCard.fullDeck)
        if (!used.contains(card)) card,
    ];
    final needed = 5 - board.length;

    var win = 0;
    var tie = 0;
    var lose = 0;

    void score(List<PlayingCard> extra) {
      final full = [...board, ...extra];
      final result = HandStrength.best([...hero, ...full])
          .compareTo(HandStrength.best([...villain, ...full]));
      if (result > 0) {
        win++;
      } else if (result == 0) {
        tie++;
      } else {
        lose++;
      }
    }

    switch (needed) {
      case 0:
        score(const []);
      case 1:
        for (final card in deck) {
          score([card]);
        }
      case 2:
        for (var i = 0; i < deck.length - 1; i++) {
          for (var j = i + 1; j < deck.length; j++) {
            score([deck[i], deck[j]]);
          }
        }
    }

    return ExactEquity(win: win, tie: tie, lose: lose);
  }
}
