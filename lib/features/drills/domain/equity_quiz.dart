import 'dart:math';

import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/playing_card.dart';
import '../../hand_review/domain/hand_read.dart';
import '../../practice_table/domain/grading/combo_equity.dart';

/// 勝率クイズの 1 問。
///
/// 自分と相手の手札・ボードが見えている状態で、「リバーまで行ったときの
/// 自分の勝率」を当てる。正解は残りのカードをすべて数え上げた厳密な値
/// （推定ではない。AGENTS.md 原則1）。
class EquityQuizQuestion {
  EquityQuizQuestion({
    required this.hero,
    required this.villain,
    required this.board,
    required this.equity,
    required this.choices,
  }) : heroRead = HandRead.of(hero, board),
       villainRead = HandRead.of(villain, board),
       outs = _outs(hero, villain, board);

  final List<PlayingCard> hero;
  final List<PlayingCard> villain;
  final List<PlayingCard> board;

  /// 自分の勝率（0.0〜1.0。引き分けは半分として数える）。
  final double equity;

  /// 選択肢（%）。昇順。
  final List<int> choices;

  final HandRead heroRead;
  final HandRead villainRead;

  /// いま負けている側が、次の 1 枚で逆転できるカード（アウツ）。
  final EquityOuts? outs;

  bool get isFlop => board.length == 3;

  /// 正解の選択肢（勝率に一番近い 5% 刻みの値）。
  int get answer => roundToFive(equity);

  /// 数え上げたランアウト（残りのボード）の通り数。
  int get runoutCount {
    final rest = 52 - 4 - board.length;
    return isFlop ? rest * (rest - 1) ~/ 2 : rest;
  }

  static int roundToFive(double equity) =>
      ((equity * 100 / 5).round() * 5).clamp(0, 100);

  static EquityOuts? _outs(
    List<PlayingCard> hero,
    List<PlayingCard> villain,
    List<PlayingCard> board,
  ) {
    final heroNow = HandStrength.best([...hero, ...board]);
    final villainNow = HandStrength.best([...villain, ...board]);
    final compare = heroNow.compareTo(villainNow);
    if (compare == 0) return null;
    final heroBehind = compare < 0;
    final known = {...hero, ...villain, ...board};
    final cards = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        final card = PlayingCard(rank, suit);
        if (known.contains(card)) continue;
        final heroNext = HandStrength.best([...hero, ...board, card]);
        final villainNext = HandStrength.best([...villain, ...board, card]);
        final next = heroNext.compareTo(villainNext);
        if (heroBehind ? next > 0 : next < 0) cards.add(card);
      }
    }
    return EquityOuts(heroIsBehind: heroBehind, cards: cards);
  }
}

/// 負けている側のアウツ（次の 1 枚で逆転するカード）。
class EquityOuts {
  const EquityOuts({required this.heroIsBehind, required this.cards});

  final bool heroIsBehind;
  final List<PlayingCard> cards;

  int get count => cards.length;
}

/// 勝率クイズの出題役。
///
/// フロップかターンで、自分と相手に 2 枚ずつ配る。勝率が 8〜92% の
/// （どちらにも逆転の目がある）場面だけを出す。
class EquityQuizGenerator {
  EquityQuizGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  EquityQuizQuestion next() {
    while (true) {
      final deck = [
        for (final suit in CardSuit.values)
          for (final rank in CardRank.values) PlayingCard(rank, suit),
      ]..shuffle(_random);
      final boardSize = _random.nextDouble() < 0.6 ? 3 : 4;
      final hero = deck.sublist(0, 2);
      final villain = deck.sublist(2, 4);
      final board = deck.sublist(4, 4 + boardSize);
      final equity = ComboEquities.compute(
        hero: hero,
        board: board,
        combos: [villain],
      ).values.single;
      if (equity < 0.08 || equity > 0.92) continue;
      return EquityQuizQuestion(
        hero: hero,
        villain: villain,
        board: board,
        equity: equity,
        choices: _choices(EquityQuizQuestion.roundToFive(equity)),
      );
    }
  }

  /// 正解と、10 ポイント以上離れた 3 つの選択肢。
  List<int> _choices(int answer) {
    final candidates = [
      for (final delta in const [-30, -20, -10, 10, 20, 30])
        if (answer + delta >= 5 && answer + delta <= 95) answer + delta,
    ]..shuffle(_random);
    final picked = <int>[answer];
    for (final candidate in candidates) {
      if (picked.length == 4) break;
      if (picked.every((p) => (p - candidate).abs() >= 10)) {
        picked.add(candidate);
      }
    }
    return picked..sort();
  }
}
