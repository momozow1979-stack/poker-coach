import 'dart:math';

import '../../../shared/models/poker_action.dart';
import '../../../shared/models/street.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../../practice_table/domain/grading/decision_grade.dart';
import '../../practice_table/domain/grading/decision_grader.dart';
import '../../practice_table/domain/practice_deck.dart';
import '../../practice_table/domain/practice_event.dart';
import '../../practice_table/domain/practice_hand_engine.dart';
import '../../practice_table/domain/practice_hand_state.dart';
import '../../practice_table/domain/practice_opponent.dart';

/// ブラフ練習の 1 問。
///
/// 「AI相手に練習」と同じ相手（決まった打ち方の AI）と同じ採点を使う。
/// 相手がチェックしてきて、自分の手が相手の範囲に対して勝率 50% 未満の
/// （= 勝ちたいならブラフを考える）場面を、実際に 1 ハンド進めて作る。
class BluffSpot {
  const BluffSpot({required this.events, required this.grade});

  /// この場面までに起きたこと（[PracticeHandState.replay] で再現できる）。
  final List<PracticeEvent> events;

  /// 各選択肢（チェック・各ベット額）の採点。
  final PracticeDecisionGrade grade;

  PracticeHandState get hand => PracticeHandState.replay(events);

  /// チェック（あきらめる）の採点。
  PracticeOptionGrade get check => grade.gradeOf(PokerActionType.check, null)!;

  /// ベット額ごとの採点（小さい順）。オールインは除く。
  List<PracticeOptionGrade> get bets => [
    for (final option in grade.options)
      if (option.option.action == PokerActionType.bet) option,
  ]..sort((a, b) => a.option.sizeBb!.compareTo(b.option.sizeBb!));

  /// 一番得な選択（損得が同じなら、出す額が小さいほう）。
  PracticeOptionGrade get best {
    final candidates = [check, ...bets];
    candidates.sort((a, b) {
      final byEv = (b.evBb ?? 0) - (a.evBb ?? 0);
      if (byEv.abs() > 1e-9) return byEv > 0 ? 1 : -1;
      return (a.heroAddBb ?? 0).compareTo(b.heroAddBb ?? 0);
    });
    return candidates.first;
  }

  /// ブラフ（ベット）のほうが得な場面か。
  bool get shouldBluff => best.option.action == PokerActionType.bet;
}

/// ブラフ練習の出題役。
///
/// BTN（あなた）がオープンし、AI（BB）がコールしたハンドを進める。
/// 出題するストリート（フロップ 4 割・ターン 3 割・リバー 3 割）まではチェックで
/// 進め、そこで AI がチェックしてきて、あなたの勝率が [maxEquity] 未満なら出題する。
/// 勝率が高ければ（ブラフの練習にならないので）チェックして先へ進む。
/// AI がベットしてきたら、そのハンドは捨てて配り直す。
class BluffSpotGenerator {
  BluffSpotGenerator({
    required this.opponent,
    required this.grader,
    Random? random,
    this.maxEquity = 0.5,
  }) : _random = random ?? Random();

  final PracticeOpponent opponent;
  final PracticeDecisionGrader grader;
  final double maxEquity;
  final Random _random;

  /// 重い計算（相手の範囲と勝率の数え上げ）を挟むので、1 回ごとに処理を
  /// 譲り、Web でも画面が固まらないようにする。
  Future<BluffSpot> next() async {
    for (var attempt = 0; attempt < 200; attempt++) {
      final spot = await _tryOneHand();
      if (spot != null) return spot;
    }
    throw StateError('ブラフの場面を作れませんでした');
  }

  Future<BluffSpot?> _tryOneHand() async {
    final engine = PracticeHandEngine(deck: PracticeDeck(_random));
    engine.apply(Actor.hero, PokerActionType.raise, sizeBb: 2.5);
    _driveVillain(engine);
    // AI がコールしなければ（降りた・3 ベットした）この手は使わない。
    if (engine.state.isOver || engine.state.street == Street.preflop) {
      return null;
    }

    // フロップに偏らないよう、出題するストリートを先に決めておき、
    // それより前はチェックで進める。
    final roll = _random.nextDouble();
    final target = roll < 0.4
        ? Street.flop
        : (roll < 0.7 ? Street.turn : Street.river);

    while (!engine.state.isOver) {
      final state = engine.state;
      if (state.actorToAct != Actor.hero) return null;
      final choices = state.choices!;
      if (choices.facingBet || !choices.choices.contains(PokerActionType.bet)) {
        return null;
      }
      if (state.street.index < target.index) {
        engine.apply(Actor.hero, PokerActionType.check);
        _driveVillain(engine);
        continue;
      }
      await Future<void>.delayed(Duration.zero);
      final grade = grader.grade(engine.events);
      final equity = grade?.heroEquity;
      if (grade != null && equity != null && equity < maxEquity) {
        return BluffSpot(events: engine.events, grade: grade);
      }
      engine.apply(Actor.hero, PokerActionType.check);
      _driveVillain(engine);
    }
    return null;
  }

  void _driveVillain(PracticeHandEngine engine) {
    while (!engine.state.isOver && engine.state.actorToAct == Actor.villain) {
      final decision = opponent.decide(engine.state);
      engine.apply(Actor.villain, decision.action, sizeBb: decision.sizeBb);
    }
  }
}
