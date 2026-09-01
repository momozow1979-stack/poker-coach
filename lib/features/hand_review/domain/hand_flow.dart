import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import 'hand_review_input.dart';

/// 行動する側。レビューはヒーローと相手の 2 人で進む前提にしている。
enum Actor { hero, villain }

/// 次に入力すべきアクションと、その場の状況。
///
/// 誰の番かはポジションから機械的に決まるので、利用者に選ばせない。
class ActionPrompt {
  const ActionPrompt({
    required this.street,
    required this.actor,
    required this.position,
    required this.choices,
    required this.aggressiveLabel,
    required this.facingBet,
    this.potBb,
    this.toCallBb,
    this.currentBetBb,
    this.isBlindOnly = false,
  });

  final Street street;
  final Actor actor;

  /// 行動する人のポジション。
  final Position position;

  /// この場面で選べるアクション。
  final List<PokerActionType> choices;

  /// 賭け金を増やすアクションの呼び名（レイズ / 3ベット / ベット など）。
  final String aggressiveLabel;

  /// 賭けに直面しているか。額が分からなくてもこれは決まる。
  final bool facingBet;

  /// 分かる範囲でのポット。サイズ未入力があると null になる。
  final double? potBb;

  /// コールに必要な額。分からなければ null。
  final double? toCallBb;

  /// このストリートで揃えるべき額。レイズの目安を出すのに使う。
  final double? currentBetBb;

  /// 直面しているのがブラインドだけか（プリフロップで誰もレイズしていない）。
  ///
  /// この場合の「必要な勝率」は意味を持たない。
  /// ポットオッズは、相手が自分の意思で賭けた額に対して考えるもので、
  /// ブラインドを埋めるだけの場面に当てはめると判断を誤らせる。
  final bool isBlindOnly;

  bool get isHero => actor == Actor.hero;

  String get actorLabel => isHero ? 'あなた' : '相手';

  /// コールに必要な勝率。額が分からなければ null。
  ///
  /// 割り算で確定する値なので、そのまま画面に出してよい。
  double? get requiredEquity {
    if (isBlindOnly) return null;
    final pot = potBb;
    final toCall = toCallBb;
    if (pot == null || toCall == null || toCall <= 0) return null;
    return toCall / (pot + toCall);
  }
}

/// いま入力すべきもの。
sealed class ReviewStep {
  const ReviewStep();
}

/// ヒーローの 2 枚がまだ入っていない。
class NeedHeroHand extends ReviewStep {
  const NeedHeroHand();
}

/// アクションの入力待ち。
class NeedAction extends ReviewStep {
  const NeedAction(this.prompt);

  final ActionPrompt prompt;
}

/// ボードカードの入力待ち。
class NeedBoard extends ReviewStep {
  const NeedBoard({required this.street, required this.count});

  final Street street;

  /// このストリートで入れる枚数。
  final int count;
}

/// 入力が終わっている。
class ReviewReady extends ReviewStep {
  const ReviewReady({required this.endedByFold, this.foldedBy});

  /// フォールドでハンドが終わったか。
  final bool endedByFold;

  /// 降りた側。[endedByFold] が false なら null。
  final Actor? foldedBy;

  /// ショーダウンまで行ったか。
  bool get sawShowdown => !endedByFold;
}

/// 1 ストリート分のベッティングラウンドを再現した結果。
class RoundSnapshot {
  const RoundSnapshot({
    required this.street,
    required this.actions,
    required this.isComplete,
    required this.endedByFold,
    required this.potBefore,
    required this.potAfter,
    required this.heroFacedCalls,
    required this.heroBets,
  });

  final Street street;
  final List<HandAction> actions;
  final bool isComplete;
  final bool endedByFold;

  /// ストリート開始時のポット。分からなければ null。
  final double? potBefore;

  /// ストリート終了時のポット。分からなければ null。
  final double? potAfter;

  /// このストリートでヒーローが直面したコールの値段。
  final List<FacedBet> heroFacedCalls;

  /// このストリートでヒーローが自分から出したベット / レイズ。
  final List<HeroBet> heroBets;
}

/// ヒーローが自分から賭けた場面。サイズの妥当性を見るのに使う。
class HeroBet {
  const HeroBet({
    required this.street,
    required this.potBeforeBb,
    required this.addedBb,
    required this.isRaise,
  });

  final Street street;

  /// 賭ける前のポット。
  final double potBeforeBb;

  /// この手番で追加で出した額。
  final double addedBb;

  final bool isRaise;

  /// ポットに対する割合。0.75 ならポットの75%。
  double get potFraction => potBeforeBb <= 0 ? 0 : addedBb / potBeforeBb;
}

/// ヒーローが賭けに直面した場面。ポットオッズの説明に使う。
class FacedBet {
  const FacedBet({
    required this.street,
    required this.potBb,
    required this.toCallBb,
    required this.chosen,
  });

  final Street street;

  /// 相手のベットを含んだ、その時点のポット。
  final double potBb;
  final double toCallBb;

  /// ヒーローが実際に選んだアクション。
  final PokerActionType chosen;

  /// 必要勝率。割り算で確定する。
  double get requiredEquity => toCallBb / (potBb + toCallBb);
}

/// 入力済みの内容から「次に何を入力すべきか」を決める。
///
/// ポジションが決まれば行動順は決まるので、利用者に「誰の番か」を
/// 選ばせる必要はない。ストリートが終われば自動で次のカード入力へ進む。
class HandFlow {
  HandFlow(this.input) {
    _replay();
  }

  final HandReviewInput input;

  final List<RoundSnapshot> rounds = [];

  late final ReviewStep step;

  /// レビューを実行できる状態か。
  bool get isReady => step is ReviewReady;

  /// ハンド全体でヒーローが直面した賭け。
  List<FacedBet> get heroFacedBets => [
    for (final round in rounds) ...round.heroFacedCalls,
  ];

  /// ハンド全体でヒーローが自分から出したベット / レイズ。
  List<HeroBet> get heroBets => [for (final round in rounds) ...round.heroBets];

  /// 最終ポット。分からなければ null。
  double? get finalPotBb => rounds.isEmpty ? null : rounds.last.potAfter;

  // ------------------------------------------------------------ 行動順 ----

  /// [street] で先に行動する側。
  Actor firstActorOf(Street street) {
    final order = street == Street.preflop
        ? Position.orderFor(input.tableType)
        : Position.postflopOrderFor(input.tableType);
    final hero = order.indexOf(input.heroPosition);
    final villain = order.indexOf(input.villainPosition);
    return hero <= villain ? Actor.hero : Actor.villain;
  }

  Position _positionOf(Actor actor) =>
      actor == Actor.hero ? input.heroPosition : input.villainPosition;

  String _actorKey(Actor actor) =>
      actor == Actor.hero ? HandAction.heroActor : input.villainPosition.label;

  // -------------------------------------------------------------- 再現 ----

  void _replay() {
    if (input.heroHand.length != 2) {
      step = const NeedHeroHand();
      return;
    }

    double? pot = 1.5;
    for (final street in Street.values) {
      final board = input.boardOf(street);
      final needed = _boardCountOf(street);
      if (board.length < needed) {
        step = NeedBoard(street: street, count: needed);
        return;
      }

      final round = _replayRound(street, pot);
      rounds.add(round);

      if (round.endedByFold) {
        final folder = round.actions.last.isHero ? Actor.hero : Actor.villain;
        step = ReviewReady(endedByFold: true, foldedBy: folder);
        return;
      }
      if (!round.isComplete) {
        step = NeedAction(_promptFor(street, round.actions, round.potBefore));
        return;
      }
      pot = round.potAfter;
    }

    step = const ReviewReady(endedByFold: false);
  }

  static int _boardCountOf(Street street) => switch (street) {
    Street.preflop => 0,
    Street.flop => 3,
    Street.turn => 1,
    Street.river => 1,
  };

  RoundSnapshot _replayRound(Street street, double? potBefore) {
    final actions = input.actionsOf(street);
    final state = _RoundState(street: street, pot: potBefore, input: input);

    final faced = <FacedBet>[];
    final bets = <HeroBet>[];
    for (var i = 0; i < actions.length; i++) {
      final actor = _actorAt(street, i);
      // ヒーローが自分から賭けた場面を、ポットが分かるときだけ記録する。
      if (actor == Actor.hero && actions[i].action.isAggressive) {
        final size = actions[i].sizeBb;
        final pot = state.pot;
        final mine = state.put[Actor.hero];
        if (size != null && pot != null && pot > 0 && mine != null) {
          bets.add(
            HeroBet(
              street: street,
              potBeforeBb: pot,
              addedBb: size - mine,
              isRaise: state.facingBetFor(actor),
            ),
          );
        }
      }
      // ヒーローが賭けに直面した場面を、値段が分かるときだけ記録する。
      final blindOnly = street == Street.preflop && state.aggressiveCount == 0;
      if (actor == Actor.hero && state.facingBetFor(actor) && !blindOnly) {
        final toCall = state.toCallFor(actor);
        final pot = state.pot;
        if (toCall != null && pot != null && toCall > 0) {
          faced.add(
            FacedBet(
              street: street,
              potBb: pot,
              toCallBb: toCall,
              chosen: actions[i].action,
            ),
          );
        }
      }
      state.apply(actor, actions[i]);
    }

    return RoundSnapshot(
      street: street,
      actions: actions,
      isComplete: state.isComplete,
      endedByFold: state.endedByFold,
      potBefore: potBefore,
      potAfter: state.pot,
      heroFacedCalls: faced,
      heroBets: bets,
    );
  }

  Actor _actorAt(Street street, int index) {
    final first = firstActorOf(street);
    final second = first == Actor.hero ? Actor.villain : Actor.hero;
    return index.isEven ? first : second;
  }

  ActionPrompt _promptFor(
    Street street,
    List<HandAction> actions,
    double? potBefore,
  ) {
    final state = _RoundState(street: street, pot: potBefore, input: input);
    for (var i = 0; i < actions.length; i++) {
      state.apply(_actorAt(street, i), actions[i]);
    }
    final actor = _actorAt(street, actions.length);
    final facing = state.facingBetFor(actor);

    return ActionPrompt(
      street: street,
      actor: actor,
      position: _positionOf(actor),
      facingBet: facing,
      potBb: state.pot,
      toCallBb: facing ? state.toCallFor(actor) : null,
      currentBetBb: state.currentBet,
      isBlindOnly: street == Street.preflop && state.aggressiveCount == 0,
      aggressiveLabel: state.aggressiveLabel(facing),
      choices: facing
          ? const [
              PokerActionType.fold,
              PokerActionType.call,
              PokerActionType.raise,
              PokerActionType.allIn,
            ]
          : const [
              PokerActionType.check,
              PokerActionType.bet,
              PokerActionType.allIn,
            ],
    );
  }

  /// 次に入力するアクションの `actor` 文字列。
  String get nextActorKey {
    final current = step;
    if (current is! NeedAction) return HandAction.heroActor;
    return _actorKey(current.prompt.actor);
  }
}

/// ベッティングラウンドの内部状態。
class _RoundState {
  _RoundState({
    required this.street,
    required this.pot,
    required HandReviewInput input,
  }) {
    if (street == Street.preflop) {
      // ブラインドはこのモデルに居ない人が出していることもあるが、
      // 「BB を1つ払わないと参加できない」ことは変わらない。
      currentBet = 1;
      put[Actor.hero] = _blindOf(input.heroPosition);
      put[Actor.villain] = _blindOf(input.villainPosition);
    } else {
      currentBet = 0;
      put[Actor.hero] = 0;
      put[Actor.villain] = 0;
    }
  }

  final Street street;

  /// 分かる範囲でのポット。サイズ未入力があると null になる。
  double? pot;

  /// このストリートで揃えるべき額。分からなくなったら null。
  double? currentBet;

  final Map<Actor, double?> put = {};

  /// 各自がこのストリートで行動した回数。
  final Map<Actor, int> acted = {Actor.hero: 0, Actor.villain: 0};

  bool endedByFold = false;
  bool _closed = false;

  /// 賭け金を増やすアクションが何回あったか。呼び名の決定に使う。
  int aggressiveCount = 0;

  static double _blindOf(Position position) => switch (position) {
    Position.sb => 0.5,
    Position.bb => 1,
    _ => 0,
  };

  bool get isComplete => endedByFold || _closed;

  bool facingBetFor(Actor actor) {
    final mine = put[actor];
    final bet = currentBet;
    if (bet == null || mine == null) {
      // 額が分からなくても「揃えるものが残っているか」は追える。
      return _facingUnknown[actor] ?? false;
    }
    return bet - mine > 0.0001;
  }

  final Map<Actor, bool> _facingUnknown = {};

  double? toCallFor(Actor actor) {
    final mine = put[actor];
    final bet = currentBet;
    if (bet == null || mine == null) return null;
    final diff = bet - mine;
    return diff > 0 ? diff : null;
  }

  String aggressiveLabel(bool facingBet) {
    if (street == Street.preflop) {
      return switch (aggressiveCount) {
        0 => 'レイズ',
        1 => '3ベット',
        2 => '4ベット',
        _ => '5ベット',
      };
    }
    return facingBet ? 'レイズ' : 'ベット';
  }

  void apply(Actor actor, HandAction action) {
    final other = actor == Actor.hero ? Actor.villain : Actor.hero;
    acted[actor] = (acted[actor] ?? 0) + 1;

    switch (action.action) {
      case PokerActionType.fold:
        endedByFold = true;
        return;
      case PokerActionType.check:
        _facingUnknown[other] = false;
      case PokerActionType.call:
        final bet = currentBet;
        final mine = put[actor];
        if (bet != null && mine != null) {
          pot = pot == null ? null : pot! + (bet - mine);
          put[actor] = bet;
        } else {
          pot = null;
          put[actor] = null;
        }
        _facingUnknown[other] = false;
      case PokerActionType.bet:
      case PokerActionType.raise:
      case PokerActionType.allIn:
        aggressiveCount++;
        final size = action.sizeBb;
        final mine = put[actor];
        if (size != null && mine != null) {
          pot = pot == null ? null : pot! + (size - mine);
          put[actor] = size;
          currentBet = size;
        } else {
          // 額が分からないので、以降のポットは追えない。
          pot = null;
          currentBet = null;
          put[actor] = null;
        }
        _facingUnknown[other] = true;
    }

    // 相手に揃えるものが残っておらず、双方が一度は行動していれば終わり。
    final bothActed =
        (acted[Actor.hero] ?? 0) > 0 && (acted[Actor.villain] ?? 0) > 0;
    if (bothActed && !facingBetFor(other)) _closed = true;
  }
}
