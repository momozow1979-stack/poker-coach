import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart'
    show Actor;
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grade.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/decision_grader.dart';
import 'package:ai_poker_coach/features/practice_table/domain/grading/grade_explainer.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_deck.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_hand_engine.dart';
import 'package:ai_poker_coach/features/practice_table/domain/practice_opponent.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:flutter_test/flutter_test.dart';

const _opponent = SimplePracticeOpponent();
const _grader = PracticeDecisionGrader(opponent: _opponent);

PracticeHandEngine _engine(List<String> cards) =>
    PracticeHandEngine(deck: PracticeDeck.ordered(PlayingCard.parseAll(cards)));

void _hero(PracticeHandEngine engine, PokerActionType action, {double? size}) {
  engine.apply(Actor.hero, action, sizeBb: size);
  while (!engine.state.isOver && engine.state.actorToAct == Actor.villain) {
    final decision = _opponent.decide(engine.state);
    engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
  }
}

PracticeGradeExplanation _explain(
  PracticeDecisionGrade grade,
  PokerActionType action, [
  double? size,
]) => PracticeGradeExplainer.explain(grade, grade.gradeOf(action, size)!);

String _pct(double value) => '${(value * 100).round()}%';

void main() {
  test('レンジ表の採点: AA を降りると×で、表の答えを示す', () {
    final grade = _grader.grade(_engine(['Ah', 'As', '7c', '2d']).events)!;
    final text = _explain(grade, PokerActionType.fold);

    expect(text.title, '× 損をする選択です');
    expect(text.reasons.single, contains('取れたはずの得を逃します'));
    expect(text.betterChoice, 'レンジ表の答え: レイズしてオープン（2〜3BB）');
    expect(text.note, contains('学習用の目安'));
    expect(text.ifChanged, isNotNull);
  });

  test('ベットに直面して勝率が足りない: 文章の数字が採点の数字と一致する', () {
    final engine = _engine([
      '6h',
      '5h',
      'Ac',
      '9c',
      'Ad',
      '7s',
      '2h',
      '3c',
      '4s',
    ]);
    _hero(engine, PokerActionType.raise, size: 2.5);
    final grade = _grader.grade(engine.events)!;
    final equity = _pct(grade.heroEquity!);
    final required = _pct(grade.requiredEquity!);

    final fold = _explain(grade, PokerActionType.fold);
    expect(fold.title, startsWith('○'));
    expect(fold.reasons.first, contains('勝率 $equity が必要勝率 $required に届かない'));
    expect(fold.reasons.first, contains('降りるのが得です'));
    expect(fold.betterChoice, isNull);

    final call = _explain(grade, PokerActionType.call);
    expect(call.title, startsWith('×'));
    expect(call.reasons.first, contains('コールし続けると長い目で見て損'));
    expect(
      call.numbers.map((n) => n.label),
      containsAll(['相手が持っていそうな手', 'あなたの勝率', '必要勝率（ポットオッズ）']),
    );
    expect(call.ifChanged, contains('コールが得になります'));
    expect(call.note, contains('簡略化'));
  });

  test('リバーで全員降りるベットは「降りてもらうだけで得」と説明する', () {
    final engine = _engine([
      'Jh',
      'Td',
      'Ks',
      'Qd',
      '2c',
      '7s',
      '9d',
      '3c',
      '4s',
    ]);
    _hero(engine, PokerActionType.raise, size: 2.5);
    _hero(engine, PokerActionType.check);
    _hero(engine, PokerActionType.check);
    final grade = _grader.grade(engine.events)!;
    final bet = grade.options.firstWhere(
      (g) => g.option.action == PokerActionType.bet,
    );

    final text = PracticeGradeExplainer.explain(grade, bet);
    expect(text.title, startsWith('○'));
    expect(text.reasons.first, contains('相手はこのベットに 100% 降ります'));
    expect(text.reasons.first, contains('降りてもらうだけで得をします'));

    final check = _explain(grade, PokerActionType.check);
    expect(check.title, startsWith('×'));
    expect(check.reasons.first, contains('チェックはその得を逃しています'));
    // 損得が同じ賭けは、出す額が小さい順に並べる（オールインを先頭にしない）。
    expect(check.betterChoice, startsWith('一番得な選択: ${bet.option.label}'));

    // 全員が降りるなら、オールインも損得は同じ○だが、小さく賭ける方を勧める。
    final allIn = _explain(grade, PokerActionType.allIn);
    expect(allIn.title, startsWith('○'));
    expect(
      allIn.reasons,
      contains(contains('同じ得なら、${bet.option.label}のように賭ける額が小さい方が')),
    );
    expect(
      text.reasons.where((r) => r.startsWith('同じ得なら')),
      isEmpty,
      reason: '一番小さいベットには、より小さい選択肢を勧めない',
    );
  });

  group('勝率が 0% / 100% と表示される場面で、起こりえない条件を書かない', () {
    PracticeDecisionGrade facingBet(
      double equity,
      PracticeVerdict callVerdict,
    ) => PracticeDecisionGrade(
      basis: GradingBasis.versusOpponent,
      street: Street.river,
      potBb: 13,
      toCallBb: 3,
      rangeComboCount: 41,
      heroEquity: equity,
      requiredEquity: 3 / 16,
      options: [
        PracticeOptionGrade(
          option: const PracticeOption(PokerActionType.fold),
          verdict: callVerdict == PracticeVerdict.good
              ? PracticeVerdict.bad
              : PracticeVerdict.good,
          evBb: 0,
        ),
        PracticeOptionGrade(
          option: const PracticeOption(PokerActionType.call),
          verdict: callVerdict,
          evBb: equity * 16 - 3,
        ),
      ],
    );

    test('0%: 「必要勝率が 0% を下回ったら」とは書かない', () {
      final grade = facingBet(0.001, PracticeVerdict.bad);
      for (final action in [PokerActionType.call, PokerActionType.fold]) {
        final text = _explain(grade, action);
        expect(text.reasons.first, contains('ほとんど勝てません（勝率 0%）'));
        expect(text.ifChanged, isNot(contains('0% を下回')));
      }
      expect(
        _explain(grade, PokerActionType.fold).reasons.first,
        endsWith('降りるのが得です。'),
      );
    });

    test('100%: 「必要勝率が 100% を超えたら」とは書かない', () {
      final grade = facingBet(0.999, PracticeVerdict.good);
      final text = _explain(grade, PokerActionType.call);
      expect(text.reasons.first, contains('ほぼ勝っています（勝率 100%）'));
      expect(text.ifChanged, isNot(contains('100% を超え')));
    });
  });

  test('プリフロップの推定値は「約」「誤差」「ランダムに試した推定」と明記する', () {
    final engine = _engine(['Ah', 'Ks', 'Qc', 'Qd']);
    _hero(engine, PokerActionType.raise, size: 2.5);
    final grade = _grader.grade(engine.events)!;

    final text = _explain(grade, PokerActionType.call);
    final equity = text.numbers.firstWhere((n) => n.label == 'あなたの勝率');
    expect(equity.value, startsWith('約'));
    expect(equity.value, contains('誤差 ±'));
    expect(equity.note, contains('ランダムに試した推定'));
  });
}
