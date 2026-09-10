import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/street.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../../range_chart/domain/range_notation.dart';
import 'practice_hand_state.dart';

/// AI（ヴィラン）の1つの判断。
class PracticeOpponentDecision {
  const PracticeOpponentDecision(this.action, {this.sizeBb});

  final PokerActionType action;

  /// ベット / レイズのときの、揃える額（BB）。
  final double? sizeBb;
}

abstract interface class PracticeOpponent {
  PracticeOpponentDecision decide(PracticeHandState state);
}

/// v1 用の、簡易ロジックのみで動く対戦相手。
///
/// **捏造防止のための設計上の注意**: ヒーローの手札は一切参照しない。
/// 実際の対戦で相手が見えるのは自分の手札とボードだけであり、ヒーローの
/// 手札を使って判断させると「相手が読心術を持つ」チートになってしまう。
/// プリフロップはレンジ階層（ソルバー検証済みではない、一般的なタイト目の
/// 目安 — 画面側でも「目安」と明記すること）、フロップ以降は自分の役の
/// 強さだけで判断する。ブラフは打たない（v1 の割り切り。挙動が読みやすく、
/// 説明もしやすいのを優先した）。
class SimplePracticeOpponent implements PracticeOpponent {
  const SimplePracticeOpponent();

  /// プリフロップでヒーローのオープンに対して 3bet するレンジ。
  static final Set<String> _threeBetRange = RangeNotation.expand('QQ+,AKs,AKo');

  /// プリフロップでコール（フラット）するレンジ。
  static final Set<String> _callRange = RangeNotation.expand(
    '22+,A2s+,K8s+,Q9s+,J9s+,T8s+,97s+,86s+,75s+,64s+,54s,'
    'A9o+,KTo+,QTo+,JTo',
  );

  @override
  PracticeOpponentDecision decide(PracticeHandState state) {
    final choices = state.choices;
    if (choices == null || choices.actor != Actor.villain) {
      throw StateError('ヴィランの番ではありません: ${choices?.actor}');
    }
    return state.street == Street.preflop
        ? _preflopDecision(state, choices)
        : _postflopDecision(state, choices);
  }

  PracticeOpponentDecision _preflopDecision(
    PracticeHandState state,
    PracticeActionChoices choices,
  ) {
    final hand = StartingHand.fromCards(
      state.villainCards[0],
      state.villainCards[1],
    );

    if (!choices.facingBet) {
      // 誰も上げていない（自分から動ける）場面はこのシナリオでは起きない
      // （BTN が必ず先にオープンするため）が、念のためチェックにしておく。
      return const PracticeOpponentDecision(PokerActionType.check);
    }
    if (_threeBetRange.contains(hand.code)) {
      final size = choices.presetSizesBb.isNotEmpty
          ? choices.presetSizesBb.last
          : choices.toCallBb * 3;
      return PracticeOpponentDecision(PokerActionType.raise, sizeBb: size);
    }
    if (_callRange.contains(hand.code)) {
      return const PracticeOpponentDecision(PokerActionType.call);
    }
    return const PracticeOpponentDecision(PokerActionType.fold);
  }

  PracticeOpponentDecision _postflopDecision(
    PracticeHandState state,
    PracticeActionChoices choices,
  ) {
    final strength = HandStrength.best([...state.villainCards, ...state.board]);
    final power = strength.category.power;

    // 強い役（スリーカード以上）: 自分から賭ける／レイズする。
    if (power >= HandCategory.trips.power) {
      return _betOrRaise(choices, fraction: 0.66);
    }
    // 中程度（ツーペア・ワンペア）: 賭けられたら受けるが、自分からは
    // 小さめにしか賭けない。
    if (power >= HandCategory.onePair.power) {
      if (choices.facingBet) {
        return const PracticeOpponentDecision(PokerActionType.call);
      }
      return _betOrRaise(choices, fraction: 0.33);
    }
    // 弱い役: 賭けられたら降りる。賭けられていなければチェック。
    if (choices.facingBet) {
      return const PracticeOpponentDecision(PokerActionType.fold);
    }
    return const PracticeOpponentDecision(PokerActionType.check);
  }

  PracticeOpponentDecision _betOrRaise(
    PracticeActionChoices choices, {
    required double fraction,
  }) {
    final action = choices.facingBet
        ? PokerActionType.raise
        : PokerActionType.bet;
    final presets = choices.presetSizesBb;
    if (presets.isEmpty) {
      return PracticeOpponentDecision(action, sizeBb: choices.toCallBb);
    }
    // プリセットのうち、狙った割合に一番近いものを選ぶ。
    final target = choices.potBb * fraction;
    final closest = presets.reduce(
      (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
    );
    return PracticeOpponentDecision(action, sizeBb: closest);
  }
}
