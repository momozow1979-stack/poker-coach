import '../../../../shared/models/poker_action.dart';
import '../../../../shared/models/street.dart';
import '../../../range_chart/domain/range_action.dart';
import '../practice_hand_state.dart';
import 'decision_grade.dart';
import 'decision_grader.dart';

/// アクションを選んだ「理由」の選択肢。
///
/// 「何を選んだか」だけでなく「なぜそう考えたか」を答えてもらい、その理由が
/// 計算した数字に照らして成り立っているかも採点する（思考の流れを身に付ける
/// ため）。どの理由も、正しいかどうかを計算から導ける文だけにしている
/// （AGENTS.md ルール1: 数字を捏造しない）。
enum DecisionReason {
  rangeOpen('レンジ表でオープンする手だから'),
  rangeFold('レンジ表でオープンしない手だから'),
  value('強い手で、弱い手に払ってもらうため（バリュー）'),
  bluff('相手を降ろすため（ブラフ）'),
  semiBluff('ドローがあり、降りてもらえなくても完成で勝てるため（セミブラフ）'),
  potOdds('勝率がポットオッズに見合うから'),
  drawImplied('ドローの完成を狙うため'),
  notEnoughEquity('勝率が必要勝率に届かないから'),
  potControl('勝ってはいそうだが、ポットを大きくしたくないから'),
  giveUp('手が弱く、賭けても降ろせないから'),
  trap('強い手なので、相手に賭けさせるため（スロープレイ）'),
  unsure('なんとなく（理由をうまく言えない）');

  const DecisionReason(this.label);

  final String label;

  static DecisionReason? byName(String? name) {
    for (final reason in values) {
      if (reason.name == name) return reason;
    }
    return null;
  }

  /// [action] を選んだときに出す理由の候補。どれも「本当ならその
  /// アクションを正当化する」文で、どれが本当かは場面で変わる。
  /// 候補が [unsure] しか無い場面（プリフロップのリンプなど）は空にして、
  /// 理由を聞かない。
  static List<DecisionReason> optionsFor(
    PracticeHandState hand,
    PokerActionType action,
  ) {
    final reasons = PracticeDecisionGrader.isOpeningDecision(hand)
        ? switch (action) {
            PokerActionType.bet ||
            PokerActionType.raise ||
            PokerActionType.allIn => const [rangeOpen],
            PokerActionType.fold => const [rangeFold],
            PokerActionType.call ||
            PokerActionType.check => const <DecisionReason>[],
          }
        : _versusOpponent(hand, action);
    if (reasons.isEmpty) return const [];
    return [...reasons, unsure];
  }

  static List<DecisionReason> _versusOpponent(
    PracticeHandState hand,
    PokerActionType action,
  ) {
    // ドローは「あと 1 枚で完成」を待てるフロップ・ターンだけ。
    final canDraw = hand.street == Street.flop || hand.street == Street.turn;
    return switch (action) {
      PokerActionType.bet ||
      PokerActionType.raise ||
      PokerActionType.allIn => [value, bluff, if (canDraw) semiBluff],
      PokerActionType.call => [potOdds, if (canDraw) drawImplied],
      PokerActionType.fold => const [notEnoughEquity],
      PokerActionType.check => const [potControl, giveUp, trap],
    };
  }
}

/// 理由の判定。
enum ReasonVerdict {
  /// 数字に照らして成り立っている。
  correct('○'),

  /// 成り立っていない。
  wrong('×'),

  /// 「なんとなく」を選んだ。
  unsure('？');

  const ReasonVerdict(this.symbol);

  final String symbol;
}

/// 選んだ理由への判定と、その根拠の説明。
class ReasonGrade {
  const ReasonGrade({
    required this.reason,
    required this.verdict,
    required this.explanation,
  });

  final DecisionReason reason;
  final ReasonVerdict verdict;

  /// なぜ成り立つ / 成り立たないか（計算した数字だけを使う）。
  final String explanation;

  String get title => switch (verdict) {
    ReasonVerdict.correct => '理由も合っています',
    ReasonVerdict.wrong => '理由が数字と合っていません',
    ReasonVerdict.unsure => '理由が言えるようになるともっと伸びます',
  };
}

/// 選んだ理由が、採点で計算した数字に照らして成り立つかを判定する。
abstract final class ReasonGrader {
  static String _pct(double value) => '${(value * 100).round()}%';

  static ReasonGrade grade(
    PracticeDecisionGrade grade,
    PracticeOptionGrade chosen,
    DecisionReason reason,
  ) {
    final (ok, text) = switch (reason) {
      DecisionReason.rangeOpen => _rangeOpen(grade),
      DecisionReason.rangeFold => _rangeFold(grade),
      DecisionReason.value => _value(chosen),
      DecisionReason.bluff => _bluff(chosen),
      DecisionReason.semiBluff || DecisionReason.drawImplied => _draw(grade),
      DecisionReason.potOdds => _potOdds(grade),
      DecisionReason.notEnoughEquity => _notEnough(grade),
      DecisionReason.potControl => _potControl(grade),
      DecisionReason.giveUp => _giveUp(grade),
      DecisionReason.trap => _trap(grade),
      DecisionReason.unsure => (
        null,
        '迷ったときは「勝率は足りているか」「相手は降りるか・払ってくれるか」の'
            '2つを考えると、理由を言葉にしやすくなります。',
      ),
    };
    return ReasonGrade(
      reason: reason,
      verdict: ok == null
          ? ReasonVerdict.unsure
          : (ok ? ReasonVerdict.correct : ReasonVerdict.wrong),
      explanation: text,
    );
  }

  static (bool?, String) _rangeOpen(PracticeDecisionGrade grade) {
    final hand = grade.heroHandCode ?? 'この手';
    return switch (grade.rangeAction) {
      RangeAction.raise => (true, '$hand はレンジ表でオープンする手です。'),
      RangeAction.mixed => (true, '$hand はレンジ表で「オープンしても降りてもよい」境目の手です。'),
      _ => (false, '$hand はレンジ表ではオープンしない手です。'),
    };
  }

  static (bool?, String) _rangeFold(PracticeDecisionGrade grade) {
    final hand = grade.heroHandCode ?? 'この手';
    return switch (grade.rangeAction) {
      RangeAction.raise => (false, '$hand はレンジ表でオープンする手です。'),
      RangeAction.mixed => (true, '$hand はレンジ表で「オープンしても降りてもよい」境目の手です。'),
      _ => (true, '$hand はレンジ表でオープンしない手です。'),
    };
  }

  static (bool?, String) _value(PracticeOptionGrade chosen) {
    final called = chosen.equityWhenCalled;
    if (called == null) {
      return (
        false,
        'この額だと、相手はコールしてきません（降りるかレイズしてくる）。'
            '払ってもらう狙いは成り立ちません。',
      );
    }
    return called >= 0.5
        ? (
            true,
            'コールしてくる手に対する勝率は ${_pct(called)}。'
                '払ってくれる手より強いので、賭けるほど得をします。',
          )
        : (
            false,
            'コールしてくる手に対する勝率は ${_pct(called)} しかありません。'
                '払ってくれるのは自分より強い手が中心で、バリューになっていません。',
          );
  }

  static (bool?, String) _bluff(PracticeOptionGrade chosen) {
    final folds = chosen.foldRate;
    final needed = chosen.breakEvenFoldRate;
    if (folds == null || needed == null) {
      return (false, '降ろす狙いを確かめられる数字がありません。');
    }
    return folds >= needed
        ? (
            true,
            '相手は ${_pct(folds)} 降ります。降ろすだけで元が取れるのに必要なのは '
                '${_pct(needed)} なので、ブラフとして成り立っています。',
          )
        : (
            false,
            '相手が降りるのは ${_pct(folds)} だけで、元を取るのに必要な '
                '${_pct(needed)} に届きません。降ろす狙いは成り立っていません。',
          );
  }

  static (bool?, String) _draw(PracticeDecisionGrade grade) {
    final draws = grade.heroDraws;
    return draws.isEmpty
        ? (false, '完成を狙えるドロー（あと 1 枚で完成するもの）がありません。')
        : (true, 'ドローがあります: ${draws.join('、')}。');
  }

  static (bool?, String) _potOdds(PracticeDecisionGrade grade) {
    final equity = grade.heroEquity;
    final required = grade.requiredEquity;
    if (equity == null || required == null) {
      return (false, '勝率を比べられる数字がありません。');
    }
    return equity >= required
        ? (true, '勝率 ${_pct(equity)} が、必要勝率 ${_pct(required)} 以上あります。')
        : (false, '勝率 ${_pct(equity)} は、必要勝率 ${_pct(required)} に届いていません。');
  }

  static (bool?, String) _notEnough(PracticeDecisionGrade grade) {
    final (ok, text) = _potOdds(grade);
    if (grade.heroEquity == null || grade.requiredEquity == null) {
      return (ok, text);
    }
    return (ok == false, text);
  }

  /// 一番小さいベット（チェックの代わりに賭けた場合の、最も控えめな選択肢）。
  static PracticeOptionGrade? _smallestBet(PracticeDecisionGrade grade) {
    PracticeOptionGrade? smallest;
    for (final option in grade.options) {
      if (option.option.sizeBb == null || !option.option.action.isAggressive) {
        continue;
      }
      if (smallest == null ||
          (option.heroAddBb ?? 0) < (smallest.heroAddBb ?? 0)) {
        smallest = option;
      }
    }
    return smallest;
  }

  static (bool?, String) _potControl(PracticeDecisionGrade grade) {
    final equity = grade.heroEquity;
    final bet = _smallestBet(grade);
    if (equity == null || bet == null) {
      return (false, '確かめられる数字がありません。');
    }
    final called = bet.equityWhenCalled;
    if (equity < 0.5) {
      return (false, '相手の手全体に対する勝率は ${_pct(equity)} で、勝っている側ではありません。');
    }
    if (called == null) {
      return (
        false,
        '勝率は ${_pct(equity)} ありますが、${bet.option.label} だと相手は'
            'コールしてきません。ポットが大きくなる心配はありません。',
      );
    }
    return called < 0.5
        ? (
            true,
            '相手の手全体には勝率 ${_pct(equity)} ですが、${bet.option.label} に'
                'コールしてくる手には ${_pct(called)}。賭けると強い手だけが残ります。',
          )
        : (
            false,
            '${bet.option.label} にコールしてくる手にも勝率 ${_pct(called)} あり、'
                'ポットを大きくしても損になりにくい場面です。',
          );
  }

  static (bool?, String) _giveUp(PracticeDecisionGrade grade) {
    final equity = grade.heroEquity;
    final bet = _smallestBet(grade);
    if (equity == null || bet == null) {
      return (false, '確かめられる数字がありません。');
    }
    if (equity >= 0.5) {
      return (false, '相手の手全体に対する勝率は ${_pct(equity)} あり、弱い手ではありません。');
    }
    final folds = bet.foldRate ?? 0;
    final needed = bet.breakEvenFoldRate ?? 1;
    return folds < needed
        ? (
            true,
            '勝率は ${_pct(equity)}。${bet.option.label} でも相手が降りるのは '
                '${_pct(folds)} で、必要な ${_pct(needed)} に届きません。',
          )
        : (
            false,
            '勝率は ${_pct(equity)} ですが、${bet.option.label} なら相手は '
                '${_pct(folds)} 降ります（必要なのは ${_pct(needed)}）。賭ければ降ろせます。',
          );
  }

  static (bool?, String) _trap(PracticeDecisionGrade grade) {
    final equity = grade.heroEquity;
    final bet = _smallestBet(grade);
    if (equity == null || bet == null) {
      return (false, '確かめられる数字がありません。');
    }
    if (equity < 0.5) {
      return (false, '相手の手全体に対する勝率は ${_pct(equity)} で、強い手ではありません。');
    }
    final folds = bet.foldRate ?? 0;
    return folds >= 0.5
        ? (
            true,
            '勝率は ${_pct(equity)}。${bet.option.label} でも相手の ${_pct(folds)} が'
                '降りてしまうので、チェックで相手を残す考えは筋が通ります。',
          )
        : (
            false,
            '勝率は ${_pct(equity)} ありますが、${bet.option.label} に降りるのは '
                '${_pct(folds)} だけ。賭けても相手は残るので、罠にする理由は薄いです。',
          );
  }
}
