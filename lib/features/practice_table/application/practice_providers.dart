import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/poker_action.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../../profile/application/learning_providers.dart'
    show keyValueStoreProvider;
import '../domain/grading/decision_grade.dart';
import '../domain/grading/decision_grader.dart';
import '../domain/grading/decision_reason.dart';
import '../domain/grading/grade_explainer.dart';
import '../domain/grading/hand_reviewer.dart';
import '../domain/practice_deck.dart';
import '../domain/practice_hand_engine.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_repository.dart';
import '../domain/practice_hand_state.dart';
import '../domain/practice_opponent.dart';
import '../domain/tendency/practice_tendency.dart';
import '../infrastructure/local_practice_hand_repository.dart';
import '../infrastructure/local_practice_log_repository.dart';

final practiceHandRepositoryProvider = Provider<PracticeHandRepository>(
  (ref) => LocalPracticeHandRepository(ref.watch(keyValueStoreProvider)),
);

final practiceLogRepositoryProvider = Provider<LocalPracticeLogRepository>(
  (ref) => LocalPracticeLogRepository(ref.watch(keyValueStoreProvider)),
);

/// 練習の記録から見た打ち方の傾向。ハンドの記録が増えるたびに読み直す。
final practiceTendencyProvider = FutureProvider<PracticeTendency>((ref) async {
  final logs = await ref.watch(practiceLogRepositoryProvider).all();
  return PracticeTendency.analyze(logs);
});

/// 新しいハンドを配る山札の作り方。テストでは配る札を固定するために
/// 差し替える。
final practiceDeckFactoryProvider = Provider<PracticeDeck Function()>(
  (ref) => PracticeDeck.new,
);

/// 保存済みの練習ハンド履歴。ハンドが終わるたびに無効化して読み直す。
final practiceHistoryProvider = FutureProvider<List<PracticeHandRecord>>(
  (ref) => ref.watch(practiceHandRepositoryProvider).recent(),
);

/// 対戦相手の AI。プレイ・初心者モードの判定・振り返りの採点が
/// 必ず同じ打ち方を使うよう、ここ 1 か所で決める。
final practiceOpponentProvider = Provider<PracticeOpponent>(
  (ref) => const SimplePracticeOpponent(),
);

final practiceGraderProvider = Provider<PracticeDecisionGrader>(
  (ref) =>
      PracticeDecisionGrader(opponent: ref.watch(practiceOpponentProvider)),
);

/// 終わったハンドの振り返り（ヒーローの判断すべての採点）。
///
/// 採点は、そのハンドで実際に対戦した型の相手（[PracticeHandRecord.opponentStyle]）
/// の打ち方で計算する。
final practiceHandReviewProvider = FutureProvider.autoDispose
    .family<PracticeHandReview, PracticeHandRecord>(
      (ref, record) => PracticeHandReviewer.review(
        record.events,
        ref.watch(practiceGraderForStyleProvider(record.opponentStyle)),
        reasons: record.heroReasons,
      ),
    );

/// 型ごとの採点役。
final practiceGraderForStyleProvider =
    Provider.family<PracticeDecisionGrader, PracticeOpponentStyle>(
      (ref, style) => style == PracticeOpponentStyle.standard
          ? ref.watch(practiceGraderProvider)
          : PracticeDecisionGrader(
              opponent: SimplePracticeOpponent(style: style),
            ),
    );

/// 型ごとの相手。
final practiceOpponentForStyleProvider =
    Provider.family<PracticeOpponent, PracticeOpponentStyle>(
      (ref, style) => style == PracticeOpponentStyle.standard
          ? ref.watch(practiceOpponentProvider)
          : SimplePracticeOpponent(style: style),
    );

/// 初心者モードで、選んだアクションに出す判定。
class PracticeFeedback {
  const PracticeFeedback({
    required this.chosen,
    required this.grade,
    required this.explanation,
    this.reason,
    this.reasonGrade,
  });

  final PracticeOptionGrade chosen;
  final PracticeDecisionGrade grade;
  final PracticeGradeExplanation explanation;

  /// 選んだ理由（聞かなかった場面では null）。
  final DecisionReason? reason;
  final ReasonGrade? reasonGrade;
}

/// ライブプレイのいまの状態。イベント列は [PracticeHandState.replay] へ
/// そのまま渡せるので、リプレイ画面と同じ土台で描画できる。
class PracticeTableSnapshot {
  const PracticeTableSnapshot({
    required this.hand,
    required this.isOpponentThinking,
    this.beginnerMode = true,
    this.isGrading = false,
    this.feedback,
    this.finishedRecord,
    this.adaptiveOpponent = false,
    this.opponentStyle = PracticeOpponentStyle.standard,
    this.targetedLeak,
  });

  final PracticeHandState hand;

  /// 「育つ相手」（あなたの多いミスを突く型に切り替わる相手）を使うか。
  final bool adaptiveOpponent;

  /// このハンドの相手の型。
  final PracticeOpponentStyle opponentStyle;

  /// 育つ相手が、どの傾向を突いているか（ふつうの型なら null）。
  final PracticeLeak? targetedLeak;

  /// AI（ヴィラン）の手番で、考えている演出を出す間 true。
  final bool isOpponentThinking;

  /// 1 手ごとに○△×と理由を出し、やり直せるモード。
  final bool beginnerMode;

  /// 採点を計算している間 true。
  final bool isGrading;

  /// 初心者モードで、選んだアクションへの判定（まだ確定していない）。
  final PracticeFeedback? feedback;

  /// ハンドが終わって保存された記録。振り返り画面に渡す。保存が終わる
  /// までは null。
  final PracticeHandRecord? finishedRecord;
}

/// 1 ハンドの進行を、AI の応手も含めて管理する。
///
/// 画面は「いまの状態を見る」「ヒーローのアクションを送る」だけでよく、
/// AI の手番を進める・ストリートを送る・履歴を保存する、といった
/// 段取りはすべてここに閉じる。
class PracticeTableController extends Notifier<PracticeTableSnapshot?> {
  PracticeOpponent get _opponent =>
      ref.read(practiceOpponentForStyleProvider(_style));

  /// 採点は、実際に対戦している AI と同じ打ち方で計算する。
  PracticeDecisionGrader get _grader =>
      ref.read(practiceGraderForStyleProvider(_style));

  bool _adaptive = false;
  PracticeOpponentStyle _style = PracticeOpponentStyle.standard;
  PracticeLeak? _targetedLeak;

  PracticeHandEngine? _engine;
  bool _beginnerMode = true;
  bool _grading = false;
  PracticeFeedback? _feedback;
  PracticeHandRecord? _finishedRecord;

  /// このハンドでヒーローが選んだ理由（キーはその行動のイベント番号）。
  final Map<int, DecisionReason> _reasons = {};

  /// 同じ判断の場面で何度やり直しても計算し直さないよう、
  /// イベント数をキーに覚えておく（新しいハンドで捨てる）。
  final Map<int, PracticeDecisionGrade?> _gradeCache = {};

  @override
  PracticeTableSnapshot? build() {
    // 「育つ相手」が新しいハンドを配るときにすぐ使えるよう、傾向を
    // 先に読み込んで保持しておく。
    ref.listen(practiceTendencyProvider, (_, _) {});
    return null;
  }

  void startNewHand() {
    _chooseStyle();
    final engine = PracticeHandEngine(
      deck: ref.read(practiceDeckFactoryProvider)(),
    );
    _engine = engine;
    _feedback = null;
    _grading = false;
    _finishedRecord = null;
    _gradeCache.clear();
    _reasons.clear();
    _publish(engine, thinking: false);
    unawaited(_driveOpponentIfNeeded(engine));
  }

  /// 「育つ相手」を使うか。切り替えは次のハンドから効く（今のハンドの
  /// 相手が途中で変わると、採点の前提が崩れるため）。
  void setAdaptiveOpponent(bool enabled) {
    _adaptive = enabled;
    final engine = _engine;
    if (engine != null) _publish(engine, thinking: false);
  }

  /// 新しいハンドの相手の型を決める。育つ相手なら、直近の記録から
  /// 一番多い（突ける）ミスを突く型にする。
  void _chooseStyle() {
    final tendency = _adaptive
        ? ref.read(practiceTendencyProvider).value
        : null;
    _style = tendency?.recommendedStyle ?? PracticeOpponentStyle.standard;
    _targetedLeak = _style == PracticeOpponentStyle.standard
        ? null
        : tendency?.targetedLeak;
  }

  void setBeginnerMode(bool enabled) {
    _beginnerMode = enabled;
    // モードを切ったら、出しかけの判定は取り下げる（まだ何も確定していない）。
    if (!enabled) _feedback = null;
    final engine = _engine;
    if (engine != null) _publish(engine, thinking: false);
  }

  /// ヒーローがボタンを押した。初心者モードではすぐには確定せず、
  /// 判定を出して [confirmFeedback] か [retryDecision] を待つ。
  ///
  /// [reason] は、そのアクションを選んだ理由（聞かなかった場面では null）。
  Future<void> heroAct(
    PokerActionType action, {
    double? sizeBb,
    DecisionReason? reason,
  }) async {
    final engine = _engine;
    if (engine == null || _feedback != null || _grading) return;
    final hand = PracticeHandState.replay(engine.events);
    if (!hand.isHeroTurn) return;

    if (_beginnerMode) {
      final feedback = await _gradeChoice(engine, action, sizeBb, reason);
      // 計算の間に新しいハンドが始まっていたら、この判定は捨てる。
      if (!identical(_engine, engine)) return;
      if (feedback != null) {
        _feedback = feedback;
        _publish(engine, thinking: false);
        return;
      }
      // 採点できない場面（想定外）は、ふつうに進める。
    }
    await _applyHero(engine, action, sizeBb, reason);
  }

  /// 判定を見たうえで、そのアクションで進める。
  Future<void> confirmFeedback() async {
    final engine = _engine;
    final feedback = _feedback;
    if (engine == null || feedback == null) return;
    _feedback = null;
    await _applyHero(
      engine,
      feedback.chosen.option.action,
      feedback.chosen.option.sizeBb,
      feedback.reason,
    );
  }

  /// 判定を取り下げて、同じ場面で選び直す。
  void retryDecision() {
    final engine = _engine;
    if (engine == null || _feedback == null) return;
    _feedback = null;
    _publish(engine, thinking: false);
  }

  Future<PracticeFeedback?> _gradeChoice(
    PracticeHandEngine engine,
    PokerActionType action,
    double? sizeBb,
    DecisionReason? reason,
  ) async {
    final key = engine.events.length;
    if (!_gradeCache.containsKey(key)) {
      _grading = true;
      _publish(engine, thinking: false);
      // 「採点中」を一度描画してから重い計算に入る（Web では計算中に
      // 画面が更新されないため）。
      await Future<void>.delayed(const Duration(milliseconds: 32));
      if (!identical(_engine, engine)) return null;
      _gradeCache[key] = _grader.grade(engine.events);
      _grading = false;
    }
    final grade = _gradeCache[key];
    final chosen = grade?.gradeOf(action, sizeBb);
    if (grade == null || chosen == null) return null;
    return PracticeFeedback(
      chosen: chosen,
      grade: grade,
      explanation: PracticeGradeExplainer.explain(grade, chosen),
      reason: reason,
      reasonGrade: reason == null
          ? null
          : ReasonGrader.grade(grade, chosen, reason),
    );
  }

  Future<void> _applyHero(
    PracticeHandEngine engine,
    PokerActionType action,
    double? sizeBb,
    DecisionReason? reason,
  ) async {
    if (reason != null) _reasons[engine.events.length] = reason;
    engine.apply(Actor.hero, action, sizeBb: sizeBb);
    _publish(engine, thinking: false);
    await _driveOpponentIfNeeded(engine);
  }

  Future<void> _driveOpponentIfNeeded(PracticeHandEngine engine) async {
    var hand = PracticeHandState.replay(engine.events);
    while (!hand.isOver && hand.actorToAct == Actor.villain) {
      _publish(engine, thinking: true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      // 待っている間に別の新しいハンドが始まっていたら、この続きは無効。
      if (!identical(_engine, engine)) return;

      final decision = _opponent.decide(hand);
      engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
      hand = PracticeHandState.replay(engine.events);
      _publish(engine, thinking: false);
    }
    if (hand.isOver) await _persist(engine, hand);
  }

  Future<void> _persist(
    PracticeHandEngine engine,
    PracticeHandState hand,
  ) async {
    final repository = ref.read(practiceHandRepositoryProvider);
    final record = PracticeHandRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      events: engine.events,
      endedByFold: hand.endedByFold,
      winner: hand.winner,
      finalPotBb: hand.pot,
      heroReasons: Map.of(_reasons),
      opponentStyle: _style,
    );
    await repository.save(record);
    ref.invalidate(practiceHistoryProvider);
    unawaited(_logDecisions(record));
    // 保存している間に新しいハンドが始まっていたら、古い記録は出さない。
    if (!identical(_engine, engine)) return;
    _finishedRecord = record;
    _publish(engine, thinking: false);
  }

  /// ハンドの判断を採点して、傾向分析用に残す（画面を待たせないよう裏で）。
  Future<void> _logDecisions(PracticeHandRecord record) async {
    try {
      final review = await PracticeHandReviewer.review(
        record.events,
        ref.read(practiceGraderForStyleProvider(record.opponentStyle)),
        reasons: record.heroReasons,
      );
      if (!ref.mounted) return;
      await ref
          .read(practiceLogRepositoryProvider)
          .save(PracticeHandLog.fromReview(record, review));
      if (!ref.mounted) return;
      ref.invalidate(practiceTendencyProvider);
    } catch (_) {
      // 記録に失敗しても練習は続けられる（傾向の集計から漏れるだけ）。
    }
  }

  void _publish(PracticeHandEngine engine, {required bool thinking}) {
    state = PracticeTableSnapshot(
      hand: PracticeHandState.replay(engine.events),
      isOpponentThinking: thinking,
      beginnerMode: _beginnerMode,
      isGrading: _grading,
      feedback: _feedback,
      finishedRecord: _finishedRecord,
      adaptiveOpponent: _adaptive,
      opponentStyle: _style,
      targetedLeak: _targetedLeak,
    );
  }
}

final practiceTableProvider =
    NotifierProvider<PracticeTableController, PracticeTableSnapshot?>(
      PracticeTableController.new,
    );
