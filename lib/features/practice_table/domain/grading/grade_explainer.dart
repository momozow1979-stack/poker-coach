import '../../../../shared/models/poker_action.dart';
import '../../../range_chart/domain/range_action.dart';
import 'decision_grade.dart';

/// 判定の根拠として画面に並べる数値 1 つ。
class GradeNumber {
  const GradeNumber(this.label, this.value, {this.note});

  final String label;
  final String value;

  /// その数値が何をどう数えたものか。
  final String? note;
}

/// 選んだアクションへの判定を、初心者が読める文章にしたもの。
///
/// 文章はすべて [PracticeDecisionGrade] の数値から組み立て、数値が示して
/// いないこと（「勝率が足りている」など）は書かない。理由だけでなく、
/// 「何が変われば別の選択が良くなるか」も必ず添える（AGENTS.md ルール5）。
class PracticeGradeExplanation {
  const PracticeGradeExplanation({
    required this.verdict,
    required this.title,
    required this.reasons,
    required this.numbers,
    required this.note,
    this.betterChoice,
    this.ifChanged,
  });

  final PracticeVerdict verdict;
  final String title;
  final List<String> reasons;
  final List<GradeNumber> numbers;

  /// ○ でなかったときの、一番得な選択。
  final String? betterChoice;

  /// 何が変われば別の選択が良くなるか。
  final String? ifChanged;

  /// 判定の根拠と簡略化の注記。
  final String note;
}

abstract final class PracticeGradeExplainer {
  static PracticeGradeExplanation explain(
    PracticeDecisionGrade grade,
    PracticeOptionGrade chosen,
  ) => switch (grade.basis) {
    GradingBasis.rangeTable => _byRangeTable(grade, chosen),
    GradingBasis.versusOpponent => _versusOpponent(grade, chosen),
  };

  static String titleFor(PracticeVerdict verdict) => switch (verdict) {
    PracticeVerdict.good => '○ 良い選択です',
    PracticeVerdict.close => '△ 僅差です（条件次第）',
    PracticeVerdict.bad => '× 損をする選択です',
  };

  static String _pct(double value) => '${(value * 100).round()}%';

  // ------------------------------------------------------ レンジ表で採点 ----

  static PracticeGradeExplanation _byRangeTable(
    PracticeDecisionGrade grade,
    PracticeOptionGrade chosen,
  ) {
    final code = grade.heroHandCode ?? '';
    final tableAction = grade.rangeAction ?? RangeAction.fold;
    final plays = tableAction == RangeAction.raise;
    final borderline = tableAction == RangeAction.mixed;
    final tableLabel = plays
        ? 'オープンする手'
        : (borderline ? '境界の手（どちらでも可）' : '降りる手');

    const playsReason = 'BTN は後ろに BB しかいない一番有利な席なので、広めに参加できます。';
    const borderlineReason = 'オープンしても降りてもよい手なので、どちらも○にしています。';

    final reasons = <String>[
      switch (chosen.option.action) {
        PokerActionType.raise || PokerActionType.bet =>
          plays
              ? '$codeは、アプリのレンジ表で BTN からオープンする手です。$playsReason'
              : borderline
              ? '$codeは、レンジ表で「境界の手」です。$borderlineReason'
              : '$codeは、レンジ表では BTN でも降りる手です。参加すると、相手より弱い手で戦う場面が増えます。',
        PokerActionType.fold =>
          plays
              ? '$codeは、レンジ表で BTN からオープンする手です。降りると、取れたはずの得を逃します。'
              : borderline
              ? '$codeは、レンジ表で「境界の手」です。$borderlineReason'
              : '$codeは、レンジ表では BTN でも降りる手です。無理に参加しないのが正解です。',
        PokerActionType.call || PokerActionType.check =>
          'このアプリのレンジ表は、BTN では「レイズしてオープンする」か「降りる」かの二択です。'
              'コールだけ（リンプ）は表の想定外なので、△にしています。',
        PokerActionType.allIn =>
          plays || borderline
              ? 'レンジ表はオープンの額を 2〜3BB と想定しています。100BB 全部を賭けるのは表の想定外なので、△にしています。'
              : '$codeは、レンジ表では降りる手です。そのうえ 100BB 全部を賭けるので、負けたときの損がとても大きくなります。',
      },
    ];

    final tableAnswer = plays
        ? 'レイズしてオープン（2〜3BB）'
        : (borderline ? 'レイズしてオープン、または降りる' : '降りる');

    return PracticeGradeExplanation(
      verdict: chosen.verdict,
      title: titleFor(chosen.verdict),
      reasons: reasons,
      numbers: [
        GradeNumber('あなたの手札', code),
        GradeNumber('レンジ表での扱い', tableLabel),
      ],
      betterChoice: chosen.verdict == PracticeVerdict.good
          ? null
          : 'レンジ表の答え: $tableAnswer',
      ifChanged: '前の席の誰かがすでにレイズしていたら、使う表（vs オープン）が変わり、参加できる手はぐっと狭くなります。',
      note: '※ 根拠はアプリ同梱のレンジ表（学習用の目安）です。ソルバーで検証した頻度ではありません。',
    );
  }

  // ------------------------------------------- この AI に対する損得で採点 ----

  static PracticeGradeExplanation _versusOpponent(
    PracticeDecisionGrade grade,
    PracticeOptionGrade chosen,
  ) {
    final equity = grade.heroEquity ?? 0;
    final required = grade.requiredEquity;
    final equityText = grade.equityIsExact ? _pct(equity) : '約${_pct(equity)}';

    final numbers = <GradeNumber>[
      GradeNumber(
        '相手が持っていそうな手',
        '${grade.rangeComboCount}通り',
        note: 'ここまでの相手の行動と矛盾しない手札（すべて同じ確率として計算）',
      ),
      GradeNumber(
        'あなたの勝率',
        grade.equityIsExact
            ? equityText
            : '$equityText（誤差 ±${(grade.equityMargin * 100).toStringAsFixed(1)}%）',
        note: grade.equityIsExact
            ? 'その手札すべてに対して、残りのカードをすべて数えた値'
            : 'プリフロップは組み合わせが多すぎるため、'
                  '${grade.equitySamplesPerCombo * (grade.rangeComboCount ?? 0)}回ランダムに試した推定',
      ),
      if (required != null)
        GradeNumber(
          '必要勝率（ポットオッズ）',
          _pct(required),
          note: 'コール額 ${formatBb(grade.toCallBb)}BB ÷ コール後のポット',
        ),
    ];

    final option = chosen.option;
    if (option.action.isAggressive) {
      if (chosen.foldRate != null) {
        numbers.add(GradeNumber('このベットに相手が降りる割合', _pct(chosen.foldRate!)));
      }
      if (chosen.breakEvenFoldRate != null) {
        numbers.add(
          GradeNumber(
            'ブラフで元が取れる降りる割合',
            _pct(chosen.breakEvenFoldRate!),
            note: '賭ける額 ÷ (今のポット + 賭ける額)',
          ),
        );
      }
      if (chosen.equityWhenCalled != null) {
        numbers.add(GradeNumber('コールされたときの勝率', _pct(chosen.equityWhenCalled!)));
      }
      if ((chosen.raiseRate ?? 0) > 0) {
        numbers.add(GradeNumber('レイズし返される割合', _pct(chosen.raiseRate!)));
      }
    }

    final best = grade.goodOptions.isEmpty ? null : grade.goodOptions.first;
    final reasons = <String>[];
    String? ifChanged;

    switch (option.action) {
      case PokerActionType.fold || PokerActionType.call:
        final req = required ?? 0;
        final isCall = option.action == PokerActionType.call;
        // 勝率が 0% / 100% と表示される場面では「必要勝率が 0% を下回ったら」
        // のような、起こりえない条件を書かないよう言い方を変える。
        final shownPercent = (equity * 100).round();
        final foldIsGood = !isCall && chosen.verdict == PracticeVerdict.good;
        if (shownPercent == 0) {
          reasons.add(
            '相手が持っていそうな手すべてに対して、今のあなたの手はほとんど勝てません（勝率 $equityText）。'
            '${isCall ? 'ベットの額に関係なく、コールは損です。' : (foldIsGood ? '降りるのが得です。' : 'コールは損です。')}',
          );
          ifChanged = 'もし相手が、あなたより弱い手でもこの額をベットしてくる相手なら、コールを考える余地が出てきます。';
        } else if (shownPercent == 100) {
          reasons.add(
            'あなたの手は、相手が持っていそうな手すべてにほぼ勝っています（勝率 $equityText）。'
            '${isCall ? 'コールで得をします。' : '降りる理由はありません。'}',
          );
          ifChanged = 'もし相手が、あなたより強い手でもこの額をベットしてくる相手なら、話が変わります。';
        } else if (equity >= req) {
          reasons.add(
            '勝率 $equityText が必要勝率 ${_pct(req)} を上回っているので、'
            '${isCall ? 'コールで得をします。' : 'コールでも得ができ、降りると損です。'}',
          );
          ifChanged = 'もし相手のベットがもっと大きく、必要勝率が $equityText を超えていたら、降りる方が得になります。';
        } else {
          reasons.add(
            '勝率 $equityText が必要勝率 ${_pct(req)} に届かないので、'
            '${isCall ? 'コールし続けると長い目で見て損です。' : (foldIsGood ? '降りるのが得です。' : 'コールでは損です。')}',
          );
          ifChanged = 'もし相手のベットがもっと小さく、必要勝率が $equityText を下回っていたら、コールが得になります。';
        }
        if (chosen.impliedOddsSoftened) {
          reasons.add(
            'ただし${grade.heroDraws.join('・')}があるので、完成したときに相手から追加で取れる分'
            '（インプライドオッズ）次第では十分ありえます。計算は今のストリートまでなので、×ではなく△にしています。',
          );
        }
        if (chosen.verdict != PracticeVerdict.good &&
            best != null &&
            best.option.action.isAggressive) {
          reasons.add('${best.option.label}なら、さらに得をします。');
        }
      case PokerActionType.check:
        final bestBet = _bestAggressive(grade);
        if (bestBet == null) break;
        final fold = bestBet.foldRate ?? 0;
        final called = bestBet.equityWhenCalled;
        if (chosen.verdict == PracticeVerdict.good) {
          reasons.add(
            '${bestBet.option.label}しても相手が降りるのは ${_pct(fold)}'
            '${called != null ? '、コールされたときの勝率は ${_pct(called)}' : ''}。'
            'チェックしてこれ以上賭けずに見る（勝率 $equityText）方が得です。',
          );
          ifChanged = 'もし相手がもっと弱い手でも降りたりコールしたりする相手なら、ベットの方が得になります。';
        } else {
          reasons.add(
            '${bestBet.option.label}すると相手は ${_pct(fold)} 降ります'
            '${called != null ? '。コールされても勝率 ${_pct(called)} あります' : ''}。'
            'チェックはその得を逃しています。',
          );
          ifChanged = 'もし相手がベットにほとんど降りず、強い手でだけコールしてくる相手なら、チェックが良くなります。';
        }
      case PokerActionType.bet ||
          PokerActionType.raise ||
          PokerActionType.allIn:
        final fold = chosen.foldRate ?? 0;
        final breakEven = chosen.breakEvenFoldRate ?? 1;
        final called = chosen.equityWhenCalled;
        final raised = chosen.raiseRate ?? 0;
        final profitableBluff = fold >= breakEven;
        if (chosen.verdict == PracticeVerdict.good) {
          if (profitableBluff) {
            reasons.add(
              '相手はこのベットに ${_pct(fold)} 降ります。元を取るのに必要なのは ${_pct(breakEven)} なので、'
              '降りてもらうだけで得をします。',
            );
          }
          if (called != null && called >= 0.5) {
            reasons.add('コールしてくる手に対しても勝率 ${_pct(called)} あり、ベットで価値を取れます。');
          }
          final safer = _smallerEquallyGood(grade, chosen);
          if (safer != null) {
            reasons.add(
              '同じ得なら、${safer.option.label}のように賭ける額が小さい方が、'
              '相手の打ち方を読み違えたときの損が小さくて済みます。',
            );
          }
          ifChanged = profitableBluff
              ? 'もし相手の降りる割合が ${_pct(breakEven)} を下回る相手なら、このベットはやめた方がよくなります。'
              : 'もし相手がもっと強い手でしかコールしてこない相手なら、ベットの額を小さくするかチェックが良くなります。';
        } else {
          if (!profitableBluff) {
            reasons.add(
              '相手が降りるのは ${_pct(fold)} だけで、ブラフが元を取るのに必要な ${_pct(breakEven)} に届きません。',
            );
          }
          if (called != null && called < 0.5) {
            reasons.add('コールされたときの勝率も ${_pct(called)} しかありません。');
          }
          if (raised > 0) {
            reasons.add('相手は ${_pct(raised)} でレイズし返してきます。');
          }
          if (best != null &&
              best.option.action == option.action &&
              best.option.sizeBb != option.sizeBb) {
            reasons.add(
              '同じ${option.action.description}でも、${best.option.label}の方が得です。',
            );
          }
          ifChanged = 'もし相手が ${_pct(breakEven)} 以上降りてくれる相手なら、このベットも得になります。';
        }
    }

    if (reasons.isEmpty) {
      reasons.add('この場面で選べる中では、${best?.option.label ?? 'ほかの選択'}が一番得です。');
    }

    return PracticeGradeExplanation(
      verdict: chosen.verdict,
      title: titleFor(chosen.verdict),
      reasons: reasons,
      numbers: numbers,
      betterChoice: chosen.verdict == PracticeVerdict.good || best == null
          ? null
          : '一番得な選択: ${grade.goodOptions.map((g) => g.option.label).join('・')}',
      ifChanged: ifChanged,
      note:
          '※ この判定は、このAIの決まった打ち方に対する計算です。次のストリート以降の賭けは含めず、'
          'ここから先はこれ以上賭けずに最後まで見るものとして簡略化しています。',
    );
  }

  /// [chosen] と損得が同じで、新たに出す額がより小さい○の賭け。
  static PracticeOptionGrade? _smallerEquallyGood(
    PracticeDecisionGrade grade,
    PracticeOptionGrade chosen,
  ) {
    for (final other in grade.goodOptions) {
      if (!other.option.action.isAggressive) continue;
      if (((other.evBb ?? 0) - (chosen.evBb ?? 0)).abs() > 1e-9) continue;
      if ((other.heroAddBb ?? 0) < (chosen.heroAddBb ?? 0) - 1e-9) return other;
    }
    return null;
  }

  static PracticeOptionGrade? _bestAggressive(PracticeDecisionGrade grade) {
    PracticeOptionGrade? best;
    for (final option in grade.options) {
      if (!option.option.action.isAggressive) continue;
      if (best == null || (option.evBb ?? 0) > (best.evBb ?? 0)) best = option;
    }
    return best;
  }
}
