import '../../../shared/models/fast_hand_evaluator.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/street.dart';
import '../../practice_table/domain/practice_hand_state.dart';
import '../../practice_table/domain/practice_opponent.dart';

/// ブラフ練習の相手。
///
/// 「AI相手に練習」の相手（[SimplePracticeOpponent]）は、ペアがあれば自分から
/// 小さく賭けるので、チェックしてきた時点でペアが無いと分かり、どんな額でも
/// 100% 降りてしまう（ブラフの練習にならない）。そこでこの相手は:
///
/// - フロップ以降は、自分からは賭けずに必ずチェックする
/// - 賭けられたら、自分の手の強さと「賭けられた額がポットの何割か」で
///   受けるか降りるかを決める（額が大きいほど、受ける手が減る）
///
/// という、決まった打ち方をする。ヒーローの手札は見ない。プリフロップは
/// [SimplePracticeOpponent] と同じ。採点はこの打ち方そのものを使って
/// 計算するので、「この相手に対して」の損得になる（GTO の頻度ではない）。
class BluffDrillOpponent implements PracticeOpponent {
  const BluffDrillOpponent();

  static const _preflop = SimplePracticeOpponent();

  /// 受ける・降りるの境目（賭けられた額 ÷ 賭けられる前のポット）。
  static const middlePairMaxFraction = 0.5;
  static const strongDrawMaxFraction = 0.75;
  static const weakDrawMaxFraction = 0.4;
  static const aceHighRiverMaxFraction = 0.35;

  /// 画面で相手の打ち方を説明する文。
  static const description =
      'この相手はフロップ以降、自分からは賭けずにチェックします。'
      '賭けられたら、ツーペア以上・トップペア以上は必ず受け、'
      'それより弱いペアはポットの半分まで、'
      '強いドロー（8枚以上で完成）はポットの75%まで、'
      '弱いドロー（4〜7枚）はポットの40%まで受けます。'
      'リバーで A ハイなら、ポットの35%までは受けます。それ以外は降ります。';

  @override
  PracticeOpponentDecision decide(PracticeHandState state) {
    if (state.street == Street.preflop) return _preflop.decide(state);
    final choices = state.choices!;
    if (!choices.facingBet) {
      return const PracticeOpponentDecision(PokerActionType.check);
    }
    final toCall = choices.toCallBb;
    final fraction = toCall / (state.pot - toCall);

    final strength = classify(state.villainCards, state.board);
    final canDraw = state.street != Street.river;
    final calls = switch (strength.kind) {
      BluffDrillHandKind.twoPairOrBetter || BluffDrillHandKind.topPair => true,
      BluffDrillHandKind.weakPair => fraction <= middlePairMaxFraction + 1e-9,
      BluffDrillHandKind.draw =>
        canDraw &&
            (strength.drawOuts >= 8
                ? fraction <= strongDrawMaxFraction + 1e-9
                : (strength.drawOuts >= 4 &&
                      fraction <= weakDrawMaxFraction + 1e-9)),
      BluffDrillHandKind.aceHigh =>
        !canDraw && fraction <= aceHighRiverMaxFraction + 1e-9,
      BluffDrillHandKind.nothing => false,
    };
    return PracticeOpponentDecision(
      calls ? PokerActionType.call : PokerActionType.fold,
    );
  }

  /// 手札とボードから、受けるかどうかを決めるための強さの分類。
  ///
  /// 手札を使っていない役（ボードだけのペアなど）は、自分の役として数えない。
  static BluffDrillHand classify(
    List<PlayingCard> hole,
    List<PlayingCard> board,
  ) {
    final holeIdx = hole.map(FastHandEvaluator.indexOf).toList();
    final boardIdx = board.map(FastHandEvaluator.indexOf).toList();
    final category = FastHandEvaluator.categoryOf(
      FastHandEvaluator.score([...holeIdx, ...boardIdx]),
    );
    const strong = BluffDrillHand(BluffDrillHandKind.twoPairOrBetter);
    // ストレート・フラッシュ以上。
    if (category >= 4) return strong;

    final boardRanks = [for (final card in board) card.rank.strength];
    final maxBoard = boardRanks.reduce((a, b) => a > b ? a : b);
    int onBoard(int rank) => boardRanks.where((r) => r == rank).length;
    final pocket = hole[0].rank == hole[1].rank;
    final hits = {
      for (final card in hole)
        if (onBoard(card.rank.strength) > 0) card.rank.strength,
    };

    // セット・スリーカード・手札 2 枚を使ったツーペア。
    if (hits.any((rank) => onBoard(rank) >= 2 || pocket)) return strong;
    if (hits.length >= 2) return strong;

    final pairRank = pocket
        ? hole[0].rank.strength
        : (hits.isEmpty ? null : hits.first);
    if (pairRank != null) {
      return BluffDrillHand(
        pairRank >= maxBoard
            ? BluffDrillHandKind.topPair
            : BluffDrillHandKind.weakPair,
      );
    }

    final outs = board.length >= 5 ? 0 : _improvingCards(holeIdx, boardIdx);
    if (outs > 0) {
      return BluffDrillHand(BluffDrillHandKind.draw, drawOuts: outs);
    }
    return BluffDrillHand(
      hole.any((card) => card.rank == CardRank.ace)
          ? BluffDrillHandKind.aceHigh
          : BluffDrillHandKind.nothing,
    );
  }

  /// あと 1 枚でフラッシュかストレートになるカードの枚数（自分から見えない
  /// カードはすべて残っているものとして数える）。
  static int _improvingCards(List<int> hole, List<int> board) {
    final used = {...hole, ...board};
    final buffer = [...hole, ...board, 0];
    var count = 0;
    for (var card = 0; card < 52; card++) {
      if (used.contains(card)) continue;
      buffer[buffer.length - 1] = card;
      if (FastHandEvaluator.categoryOf(FastHandEvaluator.score(buffer)) >= 4) {
        count++;
      }
    }
    return count;
  }
}

/// 受けるかどうかの判断に使う、手の強さの種類。
enum BluffDrillHandKind {
  twoPairOrBetter,
  topPair,
  weakPair,
  draw,
  aceHigh,
  nothing,
}

class BluffDrillHand {
  const BluffDrillHand(this.kind, {this.drawOuts = 0});

  final BluffDrillHandKind kind;

  /// [BluffDrillHandKind.draw] のとき、あと 1 枚で完成するカードの枚数。
  final int drawOuts;
}
