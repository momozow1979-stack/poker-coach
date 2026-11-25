import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/playing_card.dart';
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
  const SimplePracticeOpponent({this.style = PracticeOpponentStyle.standard});

  /// 打ち方の型。「育つ相手」では、あなたの多いミスを突く型に切り替わる。
  final PracticeOpponentStyle style;

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
    // チップが足りないなどで上乗せできない場面は、コールにとどめる
    // （選べない額を出すと、揃える額が変わらず同じやり取りが続いてしまう）。
    if (_threeBetRange.contains(hand.code) &&
        choices.choices.contains(PokerActionType.raise)) {
      return PracticeOpponentDecision(
        PokerActionType.raise,
        sizeBb: choices.presetSizesBb.last,
      );
    }
    if (_threeBetRange.contains(hand.code)) {
      return const PracticeOpponentDecision(PokerActionType.call);
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
    // 小さめにしか賭けない（「バリュー多め」の型は大きめに賭ける）。
    if (power >= HandCategory.onePair.power) {
      if (choices.facingBet) {
        return const PracticeOpponentDecision(PokerActionType.call);
      }
      return _betOrRaise(
        choices,
        fraction: style == PracticeOpponentStyle.valueHeavy ? 0.66 : 0.33,
      );
    }
    // 弱い役（ペア無し）。
    final hasAce = state.villainCards.any((card) => card.rank == CardRank.ace);
    if (choices.facingBet) {
      // 「受けすぎ」の型は、A ハイでも受ける。
      if (style == PracticeOpponentStyle.callingStation && hasAce) {
        return const PracticeOpponentDecision(PokerActionType.call);
      }
      return const PracticeOpponentDecision(PokerActionType.fold);
    }
    // 「ブラフ多め」の型は、A の無いペア無しの手で小さく賭ける
    // （A ハイはショーダウンで勝てることがあるのでチェック）。
    if (style == PracticeOpponentStyle.bluffer && !hasAce) {
      return _betOrRaise(choices, fraction: 0.33);
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
      // 上乗せできる額が無い（チップが足りない等）: 受けるだけにする。
      return PracticeOpponentDecision(
        choices.facingBet ? PokerActionType.call : PokerActionType.check,
      );
    }
    // プリセットのうち、狙った割合に一番近いものを選ぶ。
    final target = choices.potBb * fraction;
    final closest = presets.reduce(
      (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
    );
    return PracticeOpponentDecision(action, sizeBb: closest);
  }
}

/// 練習相手の打ち方の型。
///
/// どれも「決まった打ち方」で、ヒーローの手札は見ない。採点はその型の
/// 打ち方そのもので計算するので、型が変わればそれに合わせた損得になる。
enum PracticeOpponentStyle {
  standard('ふつう', 'ペア以上で小さく賭け、賭けられたらペア以上で受けます。ブラフはしません。'),
  bluffer(
    'ブラフ多め',
    'ペアが無くても（A を持っていなければ）小さく賭けてきます。'
        '降りすぎる人ほど損をする相手です。',
  ),
  valueHeavy(
    'バリュー多め',
    'ペア以上で大きく（ポットの 66%）賭けてきます。ブラフはしません。'
        '受けすぎる人ほど損をする相手です。',
  ),
  callingStation(
    '受けすぎ',
    '賭けられると、ペアが無くても A ハイなら受けます。'
        'ブラフを打ちすぎる人ほど損をする相手です。',
  );

  const PracticeOpponentStyle(this.label, this.description);

  final String label;
  final String description;

  static PracticeOpponentStyle byName(String? name) =>
      values.firstWhere((style) => style.name == name, orElse: () => standard);
}
