import 'trainer_scenario.dart';

/// 1 つの設問への回答。
class TrainerAnswer {
  const TrainerAnswer({required this.spotIndex, required this.optionId});

  final int spotIndex;
  final String optionId;
}

/// シナリオ 1 本の進行状態。
///
/// 選んだ直後にその場で解説を出すため、
/// 「回答済みだがまだ次へ進んでいない」状態を [revealedOptionId] で持つ。
class TrainerSession {
  const TrainerSession({
    required this.scenario,
    this.spotIndex = 0,
    this.answers = const [],
    this.revealedOptionId,
    this.endedEarly = false,
  });

  final TrainerScenario scenario;

  /// いま表示している設問の位置（0 始まり）。
  final int spotIndex;

  final List<TrainerAnswer> answers;

  /// 回答して解説を表示中の選択肢 ID。未回答なら null。
  final String? revealedOptionId;

  /// フォールドを選んでハンドが終わったか。
  final bool endedEarly;

  bool get isAnswerRevealed => revealedOptionId != null;

  bool get isFinished => endedEarly || spotIndex >= scenario.spots.length;

  /// 全問終わっているときは null。
  TrainerSpot? get currentSpot => isFinished ? null : scenario.spots[spotIndex];

  int get answeredCount => answers.length;

  double get progress => scenario.spotCount == 0
      ? 0
      : (spotIndex + (isAnswerRevealed ? 1 : 0)) / scenario.spotCount;

  /// 回答した設問と、そこで選んだ選択肢の組。総括で使う。
  List<({TrainerSpot spot, TrainerOption option})> get review => [
    for (final answer in answers)
      (
        spot: scenario.spots[answer.spotIndex],
        option: scenario.spots[answer.spotIndex].optionById(answer.optionId),
      ),
  ];

  int countOf(TrainerVerdict verdict) =>
      review.where((entry) => entry.option.verdict == verdict).length;

  /// 「最善」で選べた割合を 0〜100 で表す。
  ///
  /// ポーカーの EV ではなく、このアプリの採点ルールでの達成度。
  /// 「悪くない」は半分ぶんとして数える。
  int get achievement {
    if (answers.isEmpty) return 0;
    final points =
        countOf(TrainerVerdict.best) * 2 + countOf(TrainerVerdict.reasonable);
    return (points * 100 / (answers.length * 2)).round();
  }

  TrainerSession copyWith({
    int? spotIndex,
    List<TrainerAnswer>? answers,
    String? revealedOptionId,
    bool clearRevealed = false,
    bool? endedEarly,
  }) {
    return TrainerSession(
      scenario: scenario,
      spotIndex: spotIndex ?? this.spotIndex,
      answers: answers ?? this.answers,
      revealedOptionId: clearRevealed
          ? null
          : revealedOptionId ?? this.revealedOptionId,
      endedEarly: endedEarly ?? this.endedEarly,
    );
  }

  /// 選択肢を選んで、その場で解説を出す。
  TrainerSession answer(String optionId) {
    if (isFinished || isAnswerRevealed) return this;
    return copyWith(
      answers: [
        ...answers,
        TrainerAnswer(spotIndex: spotIndex, optionId: optionId),
      ],
      revealedOptionId: optionId,
    );
  }

  /// 次のストリートへ進む。フォールドを選んでいた場合はそこで終了する。
  TrainerSession next() {
    final revealed = revealedOptionId;
    if (revealed == null || isFinished) return this;
    final option = scenario.spots[spotIndex].optionById(revealed);
    return copyWith(
      spotIndex: spotIndex + 1,
      clearRevealed: true,
      endedEarly: option.endsHand,
    );
  }

  /// 同じシナリオを最初からやり直す。
  TrainerSession restart() => TrainerSession(scenario: scenario);
}
