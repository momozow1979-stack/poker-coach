import 'dart:math';

import '../../../shared/models/playing_card.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../../range_chart/domain/range_action.dart';
import '../../range_chart/domain/range_entry.dart';
import '../../range_chart/domain/range_repository.dart';
import '../../range_chart/domain/range_spot.dart';

/// プリフロップ連続ドリルで押せる答え。
enum PreflopDrillAnswer {
  fold('フォールド'),
  call('コール'),
  raise('レイズ'),
  threeBet('3ベット');

  const PreflopDrillAnswer(this.label);

  final String label;

  static PreflopDrillAnswer? fromRangeAction(RangeAction action) =>
      switch (action) {
        RangeAction.fold => fold,
        RangeAction.call => call,
        RangeAction.raise => raise,
        RangeAction.threeBet => threeBet,
        RangeAction.fourBet || RangeAction.mixed => null,
      };
}

/// 1 問。どの席・どの状況で、どの 2 枚を持っているか。
class PreflopDrillQuestion {
  const PreflopDrillQuestion({
    required this.chart,
    required this.hand,
    required this.cards,
  });

  final RangeChart chart;
  final StartingHand hand;
  final List<PlayingCard> cards;

  RangeSpot get spot => chart.spot;
  RangeEntry get entry => chart.entryFor(hand);

  bool get isOpen => spot.situation == RangeSituation.openRaise;

  /// この問題で押せる答え。オープンは「降りるか上げるか」、
  /// 相手のオープンに対しては「降りる・コール・3ベット」。
  List<PreflopDrillAnswer> get choices => isOpen
      ? const [PreflopDrillAnswer.fold, PreflopDrillAnswer.raise]
      : const [
          PreflopDrillAnswer.fold,
          PreflopDrillAnswer.call,
          PreflopDrillAnswer.threeBet,
        ];

  /// レンジ表で正解になる答え。境目の手（mixed）は 2 つとも正解。
  Set<PreflopDrillAnswer> get correctAnswers {
    final entry = this.entry;
    if (entry.action == RangeAction.mixed) {
      final blend = entry.blend;
      if (blend == null) {
        // 内訳の無い境目は「参加する / 降りる」のどちらも正解にする。
        return {
          PreflopDrillAnswer.fold,
          isOpen ? PreflopDrillAnswer.raise : PreflopDrillAnswer.call,
        };
      }
      return {
        for (final action in [blend.primary, blend.secondary])
          ?PreflopDrillAnswer.fromRangeAction(action),
      };
    }
    final answer = PreflopDrillAnswer.fromRangeAction(entry.action);
    return {answer ?? PreflopDrillAnswer.fold};
  }

  /// 画面の見出し（例: 「BTN でオープンするか」「BB で BTN のオープンを受ける」）。
  String get title => isOpen
      ? '${spot.heroPosition.label} で、前の全員が降りました'
      : '${spot.heroPosition.label} で、${spot.villainPosition?.label ?? '相手'} が'
            'オープンしました';
}

/// 1 問への答えの結果。
class PreflopDrillResult {
  const PreflopDrillResult({required this.question, required this.answer});

  final PreflopDrillQuestion question;
  final PreflopDrillAnswer answer;

  bool get isCorrect => question.correctAnswers.contains(answer);
}

/// 出題を作る。
///
/// 6MAX のオープン（UTG〜SB）と、相手のオープンへの対応（vs オープン）から
/// 場面を選ぶ。手札は半分を「境目の手」（mixed、または表で隣のマスと答えが
/// 違う手）から選び、レンジの端を集中的に練習できるようにする。
/// 残りは 169 種類から均等に選ぶ（明らかな手も混ぜて全体像を保つ）。
class PreflopDrillGenerator {
  PreflopDrillGenerator({required RangeRepository ranges, Random? random})
    : _random = random ?? Random(),
      _charts = [
        for (final spot in ranges.spotsFor(TableType.sixMax))
          if (spot.situation == RangeSituation.openRaise ||
              spot.situation == RangeSituation.vsOpen)
            ?ranges.chartById(spot.id),
      ];

  final Random _random;
  final List<RangeChart> _charts;

  /// 出題できる場面（テスト・画面の説明用）。
  List<RangeChart> get charts => _charts;

  PreflopDrillQuestion next({Position? onlyPosition}) {
    final pool = onlyPosition == null
        ? _charts
        : [
            for (final chart in _charts)
              if (chart.spot.heroPosition == onlyPosition) chart,
          ];
    final chart = pool[_random.nextInt(pool.length)];
    final boundary = boundaryHands(chart);
    final hand = boundary.isNotEmpty && _random.nextBool()
        ? boundary[_random.nextInt(boundary.length)]
        : StartingHand.all[_random.nextInt(StartingHand.all.length)];
    return PreflopDrillQuestion(
      chart: chart,
      hand: hand,
      cards: _cardsFor(hand),
    );
  }

  /// 境目の手: mixed か、表で上下左右の隣のマスと答えが違う手。
  static List<StartingHand> boundaryHands(RangeChart chart) {
    final size = CardRank.values.length;
    RangeAction at(int row, int column) =>
        chart.entryFor(StartingHand.fromGrid(row, column)).action;
    return [
      for (var row = 0; row < size; row++)
        for (var column = 0; column < size; column++)
          if (at(row, column) == RangeAction.mixed ||
              [
                (row - 1, column),
                (row + 1, column),
                (row, column - 1),
                (row, column + 1),
              ].any(
                (p) =>
                    p.$1 >= 0 &&
                    p.$1 < size &&
                    p.$2 >= 0 &&
                    p.$2 < size &&
                    at(p.$1, p.$2) != at(row, column),
              ))
            StartingHand.fromGrid(row, column),
    ];
  }

  /// 具体的な 2 枚（スートはランダム）。
  List<PlayingCard> _cardsFor(StartingHand hand) {
    final suits = [...CardSuit.values]..shuffle(_random);
    final first = suits[0];
    final second = switch (hand.shape) {
      HandShape.suited => first,
      _ => suits[1],
    };
    return [PlayingCard(hand.high, first), PlayingCard(hand.low, second)];
  }
}

/// 1 セッション（決まった問題数）の進み具合。
class PreflopDrillSession {
  PreflopDrillSession(
    this._generator, {
    this.length = 20,
    this.onlyPosition,
    List<PreflopDrillQuestion>? retryQuestions,
  }) : _queue = retryQuestions == null ? null : [...retryQuestions] {
    _current = _draw();
  }

  final PreflopDrillGenerator _generator;

  /// 何問で 1 セッションか（「間違えた問題だけ」のときはその数）。
  final int length;

  /// この席だけを出題する（null ならすべての席）。
  final Position? onlyPosition;

  /// 「間違えた問題だけもう一度」のときの出題順。
  final List<PreflopDrillQuestion>? _queue;

  final List<PreflopDrillResult> results = [];
  late PreflopDrillQuestion _current;
  PreflopDrillResult? _lastResult;
  int _streak = 0;
  int _bestStreak = 0;

  PreflopDrillQuestion get current => _current;

  /// いまの問題に答えた結果（まだ答えていなければ null）。
  PreflopDrillResult? get lastResult => _lastResult;

  int get answered => results.length;
  int get correct => results.where((r) => r.isCorrect).length;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  int get total => _queue?.length ?? length;
  bool _finished = false;

  /// 最後の問題の解説を読み終えて、結果画面に進んだか。
  bool get isFinished => _finished;

  /// 最後の問題に答えたか（次は結果画面）。
  bool get isLastAnswered => answered >= total && _lastResult != null;

  List<PreflopDrillResult> get mistakes => [
    for (final result in results)
      if (!result.isCorrect) result,
  ];

  void answer(PreflopDrillAnswer answer) {
    if (_lastResult != null) return;
    final result = PreflopDrillResult(question: _current, answer: answer);
    results.add(result);
    _lastResult = result;
    if (result.isCorrect) {
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
    } else {
      _streak = 0;
    }
  }

  void next() {
    if (_lastResult == null || _finished) return;
    if (isLastAnswered) {
      _finished = true;
      return;
    }
    _lastResult = null;
    _current = _draw();
  }

  PreflopDrillQuestion _draw() {
    final queue = _queue;
    if (queue != null) return queue[results.length];
    return _generator.next(onlyPosition: onlyPosition);
  }

  /// 席ごとの（正解数, 出題数）。
  Map<Position, (int, int)> get byPosition {
    final map = <Position, (int, int)>{};
    for (final result in results) {
      final position = result.question.spot.heroPosition;
      final (ok, all) = map[position] ?? (0, 0);
      map[position] = (ok + (result.isCorrect ? 1 : 0), all + 1);
    }
    return map;
  }
}
