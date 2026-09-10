import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/poker_action.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../../profile/application/learning_providers.dart'
    show keyValueStoreProvider;
import '../domain/practice_hand_engine.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_repository.dart';
import '../domain/practice_hand_state.dart';
import '../domain/practice_opponent.dart';
import '../infrastructure/local_practice_hand_repository.dart';

final practiceHandRepositoryProvider = Provider<PracticeHandRepository>(
  (ref) => LocalPracticeHandRepository(ref.watch(keyValueStoreProvider)),
);

/// 保存済みの練習ハンド履歴。ハンドが終わるたびに無効化して読み直す。
final practiceHistoryProvider = FutureProvider<List<PracticeHandRecord>>(
  (ref) => ref.watch(practiceHandRepositoryProvider).recent(),
);

/// ライブプレイのいまの状態。イベント列は [PracticeHandState.replay] へ
/// そのまま渡せるので、リプレイ画面と同じ土台で描画できる。
class PracticeTableSnapshot {
  const PracticeTableSnapshot({
    required this.hand,
    required this.isOpponentThinking,
  });

  final PracticeHandState hand;

  /// AI（ヴィラン）の手番で、考えている演出を出す間 true。
  final bool isOpponentThinking;
}

/// 1 ハンドの進行を、AI の応手も含めて管理する。
///
/// 画面は「いまの状態を見る」「ヒーローのアクションを送る」だけでよく、
/// AI の手番を進める・ストリートを送る・履歴を保存する、といった
/// 段取りはすべてここに閉じる。
class PracticeTableController extends Notifier<PracticeTableSnapshot?> {
  static const _opponent = SimplePracticeOpponent();

  PracticeHandEngine? _engine;

  @override
  PracticeTableSnapshot? build() => null;

  void startNewHand() {
    final engine = PracticeHandEngine();
    _engine = engine;
    _publish(engine, thinking: false);
    unawaited(_driveOpponentIfNeeded(engine));
  }

  Future<void> heroAct(PokerActionType action, {double? sizeBb}) async {
    final engine = _engine;
    if (engine == null) return;
    final hand = PracticeHandState.replay(engine.events);
    if (!hand.isHeroTurn) return;

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
    );
  }
}

final practiceTableProvider =
    NotifierProvider<PracticeTableController, PracticeTableSnapshot?>(
      PracticeTableController.new,
    );
