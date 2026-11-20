import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/poker_action.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../../profile/application/learning_providers.dart'
    show keyValueStoreProvider;
import '../domain/grading/decision_grade.dart';
import '../domain/grading/decision_grader.dart';
import '../domain/grading/grade_explainer.dart';
import '../domain/practice_deck.dart';
import '../domain/practice_hand_engine.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_repository.dart';
import '../domain/practice_hand_state.dart';
import '../domain/practice_opponent.dart';
import '../infrastructure/local_practice_hand_repository.dart';

final practiceHandRepositoryProvider = Provider<PracticeHandRepository>(
  (ref) => LocalPracticeHandRepository(ref.watch(keyValueStoreProvider)),
);

/// 新しいハンドを配る山札の作り方。テストでは配る札を固定するために
/// 差し替える。
final practiceDeckFactoryProvider = Provider<PracticeDeck Function()>(
  (ref) => PracticeDeck.new,
);

/// 保存済みの練習ハンド履歴。ハンドが終わるたびに無効化して読み直す。
final practiceHistoryProvider = FutureProvider<List<PracticeHandRecord>>(
  (ref) => ref.watch(practiceHandRepositoryProvider).recent(),
);

/// 初心者モードで、選んだアクションに出す判定。
class PracticeFeedback {
  const PracticeFeedback({
    required this.chosen,
    required this.grade,
    required this.explanation,
  });

  final PracticeOptionGrade chosen;
  final PracticeDecisionGrade grade;
  final PracticeGradeExplanation explanation;
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
  });

  final PracticeHandState hand;

  /// AI（ヴィラン）の手番で、考えている演出を出す間 true。
  final bool isOpponentThinking;

  /// 1 手ごとに○△×と理由を出し、やり直せるモード。
  final bool beginnerMode;

  /// 採点を計算している間 true。
  final bool isGrading;

  /// 初心者モードで、選んだアクションへの判定（まだ確定していない）。
  final PracticeFeedback? feedback;
}

/// 1 ハンドの進行を、AI の応手も含めて管理する。
///
/// 画面は「いまの状態を見る」「ヒーローのアクションを送る」だけでよく、
/// AI の手番を進める・ストリートを送る・履歴を保存する、といった
/// 段取りはすべてここに閉じる。
class PracticeTableController extends Notifier<PracticeTableSnapshot?> {
  static const _opponent = SimplePracticeOpponent();

  /// 採点は、実際に対戦している AI と同じ打ち方で計算する。
  static const _grader = PracticeDecisionGrader(opponent: _opponent);

  PracticeHandEngine? _engine;
  bool _beginnerMode = true;
  bool _grading = false;
  PracticeFeedback? _feedback;

  /// 同じ判断の場面で何度やり直しても計算し直さないよう、
  /// イベント数をキーに覚えておく（新しいハンドで捨てる）。
  final Map<int, PracticeDecisionGrade?> _gradeCache = {};

  @override
  PracticeTableSnapshot? build() => null;

  void startNewHand() {
    final engine = PracticeHandEngine(
      deck: ref.read(practiceDeckFactoryProvider)(),
    );
    _engine = engine;
    _feedback = null;
    _grading = false;
    _gradeCache.clear();
    _publish(engine, thinking: false);
    unawaited(_driveOpponentIfNeeded(engine));
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
  Future<void> heroAct(PokerActionType action, {double? sizeBb}) async {
    final engine = _engine;
    if (engine == null || _feedback != null || _grading) return;
    final hand = PracticeHandState.replay(engine.events);
    if (!hand.isHeroTurn) return;

    if (_beginnerMode) {
      final feedback = await _gradeChoice(engine, action, sizeBb);
      // 計算の間に新しいハンドが始まっていたら、この判定は捨てる。
      if (!identical(_engine, engine)) return;
      if (feedback != null) {
        _feedback = feedback;
        _publish(engine, thinking: false);
        return;
      }
      // 採点できない場面（想定外）は、ふつうに進める。
    }
    await _applyHero(engine, action, sizeBb);
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
    );
  }

  Future<void> _applyHero(
    PracticeHandEngine engine,
    PokerActionType action,
    double? sizeBb,
  ) async {
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
    await repository.save(
      PracticeHandRecord(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        createdAt: DateTime.now(),
        events: engine.events,
        endedByFold: hand.endedByFold,
        winner: hand.winner,
        finalPotBb: hand.pot,
      ),
    );
    ref.invalidate(practiceHistoryProvider);
  }

  void _publish(PracticeHandEngine engine, {required bool thinking}) {
    state = PracticeTableSnapshot(
      hand: PracticeHandState.replay(engine.events),
      isOpponentThinking: thinking,
      beginnerMode: _beginnerMode,
      isGrading: _grading,
      feedback: _feedback,
    );
  }
}

final practiceTableProvider =
    NotifierProvider<PracticeTableController, PracticeTableSnapshot?>(
      PracticeTableController.new,
    );
