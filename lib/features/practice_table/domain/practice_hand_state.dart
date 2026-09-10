import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import 'practice_bet_sizing.dart';
import 'practice_event.dart';

/// いまの状況で選べるアクションと、賭けに関する情報。
class PracticeActionChoices {
  const PracticeActionChoices({
    required this.actor,
    required this.street,
    required this.choices,
    required this.potBb,
    required this.toCallBb,
    required this.presetSizesBb,
  });

  final Actor actor;
  final Street street;
  final List<PokerActionType> choices;
  final double potBb;

  /// コールに必要な額。直面しているベットが無ければ 0。
  final double toCallBb;

  /// ベット / レイズを選んだ場合の、額のプリセット（BB）。
  final List<double> presetSizesBb;

  bool get facingBet => toCallBb > 0;
}

/// [PracticeEvent] の列から再現した、ある時点でのハンドの状態。
///
/// ライブプレイもリプレイ画面も、この1つの再現ロジックだけを使う
/// （画面ごとに別々の状態管理を持つと、表示がずれる恐れがあるため）。
class PracticeHandState {
  const PracticeHandState({
    required this.tableType,
    required this.heroPosition,
    required this.villainPosition,
    required this.heroCards,
    required this.villainCards,
    required this.board,
    required this.street,
    required this.pot,
    required this.heroStack,
    required this.villainStack,
    required this.actorToAct,
    required this.heroToCallBb,
    required this.villainToCallBb,
    required this.isOver,
    required this.endedByFold,
    required this.winner,
    required this.actions,
  });

  final TableType tableType;
  final Position heroPosition;
  final Position villainPosition;
  final List<PlayingCard> heroCards;
  final List<PlayingCard> villainCards;
  final List<PlayingCard> board;
  final Street street;
  final double pot;

  /// 手元に残っているスタック（すでに賭けた分は含まない）。
  final double heroStack;
  final double villainStack;

  /// 次に行動する側。ハンドが終わっている、またはストリートの切り替わりを
  /// 待っている（次のボードカードが必要）ときは null。
  final Actor? actorToAct;

  /// このストリートでコールするのに必要な額。直面していなければ 0。
  final double heroToCallBb;
  final double villainToCallBb;

  final bool isOver;
  final bool endedByFold;

  /// 勝者。分け（ショーダウンでの引き分け）なら null。[isOver] が
  /// false のときは意味を持たない。
  final Actor? winner;

  /// ここまでの全アクション（画面のログ表示に使う）。
  final List<ActionOccurred> actions;

  bool get isHeroTurn => actorToAct == Actor.hero;
  bool get sawShowdown => isOver && !endedByFold;

  /// ストリートが閉じて、次のボードカード（またはハンド終了）を
  /// 待っている状態か。
  bool get isAwaitingNextStreet => !isOver && actorToAct == null;

  double stackOf(Actor actor) => actor == Actor.hero ? heroStack : villainStack;

  double toCallOf(Actor actor) =>
      actor == Actor.hero ? heroToCallBb : villainToCallBb;

  /// 次の行動者が選べる選択肢。行動できる番でなければ null。
  PracticeActionChoices? get choices {
    final actor = actorToAct;
    if (actor == null) return null;
    final toCall = toCallOf(actor);
    final facing = toCall > 0.0001;
    return PracticeActionChoices(
      actor: actor,
      street: street,
      potBb: pot,
      toCallBb: facing ? toCall : 0,
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
      presetSizesBb: PracticeBetSizing.presetsFor(
        street: street,
        potBb: pot,
        facingBb: facing ? toCall : 0,
      ),
    );
  }

  factory PracticeHandState.replay(List<PracticeEvent> events) {
    if (events.isEmpty || events.first is! HandDealt) {
      throw ArgumentError('先頭に HandDealt が必要です');
    }
    final engine = _ReplayEngine(events.first as HandDealt);
    for (final event in events.skip(1)) {
      switch (event) {
        case HandDealt():
          throw ArgumentError('HandDealt は先頭に1回だけ許されます');
        case BoardDealt():
          engine.applyBoard(event);
        case ActionOccurred():
          engine.applyAction(event);
        case HandFinished():
          engine.applyFinish(event);
      }
    }
    return engine.toState();
  }
}

/// [PracticeHandState.replay] の内部実装。可変な作業用の状態を持ち、
/// 最後に読み取り専用の [PracticeHandState] を作って返す。
class _ReplayEngine {
  _ReplayEngine(this._dealt)
    : heroStack = _dealt.startingStackBb,
      villainStack = _dealt.startingStackBb {
    // BTN(ヒーロー) が SB を折った後の 6max オープン想定: BB(ヴィラン) だけが
    // 自分のスタックから 1bb 払っている。畳んだ SB の 0.5bb は、どちらの
    // スタックからも引かれていないデッドマネーとしてポットに含める。
    villainStack -= 1;
    _streetPut[Actor.villain] = 1;
    _streetPut[Actor.hero] = 0;
    pot = 1.5;
    currentBet = 1;
    _actorToAct = Actor.hero; // プリフロップは BTN(ヒーロー) から。
  }

  final HandDealt _dealt;
  final List<PlayingCard> board = [];
  Street street = Street.preflop;
  double pot = 0;
  double heroStack;
  double villainStack;
  double currentBet = 0;
  final Map<Actor, double> _streetPut = {};
  final Map<Actor, int> _actedThisStreet = {Actor.hero: 0, Actor.villain: 0};
  Actor? _actorToAct;
  bool isOver = false;
  bool endedByFold = false;
  Actor? winner;
  final List<ActionOccurred> actions = [];

  void applyBoard(BoardDealt event) {
    board.addAll(event.cards);
    street = event.street;
    currentBet = 0;
    _streetPut[Actor.hero] = 0;
    _streetPut[Actor.villain] = 0;
    _actedThisStreet[Actor.hero] = 0;
    _actedThisStreet[Actor.villain] = 0;
    // フロップ以降は BB(ヴィラン) が先。
    _actorToAct = Actor.villain;
  }

  void applyAction(ActionOccurred event) {
    final actor = event.actor;
    final other = actor == Actor.hero ? Actor.villain : Actor.hero;
    _actedThisStreet[actor] = (_actedThisStreet[actor] ?? 0) + 1;
    actions.add(event);

    switch (event.action) {
      case PokerActionType.fold:
        endedByFold = true;
        isOver = true;
        winner = other;
        _actorToAct = null;
        return;
      case PokerActionType.check:
        break;
      case PokerActionType.call:
        _commit(actor, currentBet - (_streetPut[actor] ?? 0));
      case PokerActionType.bet:
      case PokerActionType.raise:
      case PokerActionType.allIn:
        final target = event.sizeBb ?? currentBet;
        _commit(actor, target - (_streetPut[actor] ?? 0));
        currentBet = target;
    }

    final bothActed =
        (_actedThisStreet[Actor.hero] ?? 0) > 0 &&
        (_actedThisStreet[Actor.villain] ?? 0) > 0;
    final settled = (_streetPut[actor] ?? 0) == (_streetPut[other] ?? 0);
    // ラウンドが閉じたら、行動者を空けておく。次のイベント
    // （BoardDealt か HandFinished）が状態を先に進める。
    _actorToAct = (bothActed && settled) ? null : other;
  }

  void _commit(Actor actor, double add) {
    final clamped = add.clamp(0, _stackOf(actor));
    if (actor == Actor.hero) {
      heroStack -= clamped;
    } else {
      villainStack -= clamped;
    }
    _streetPut[actor] = (_streetPut[actor] ?? 0) + clamped;
    pot += clamped;
  }

  double _stackOf(Actor actor) => actor == Actor.hero ? heroStack : villainStack;

  void applyFinish(HandFinished event) {
    isOver = true;
    endedByFold = event.endedByFold;
    winner = event.winner;
    _actorToAct = null;
  }

  PracticeHandState toState() {
    return PracticeHandState(
      tableType: _dealt.tableType,
      heroPosition: _dealt.heroPosition,
      villainPosition: _dealt.villainPosition,
      heroCards: _dealt.heroCards,
      villainCards: _dealt.villainCards,
      board: List.unmodifiable(board),
      street: street,
      pot: pot,
      heroStack: heroStack,
      villainStack: villainStack,
      actorToAct: _actorToAct,
      heroToCallBb: currentBet - (_streetPut[Actor.hero] ?? 0),
      villainToCallBb: currentBet - (_streetPut[Actor.villain] ?? 0),
      isOver: isOver,
      endedByFold: endedByFold,
      winner: winner,
      actions: List.unmodifiable(actions),
    );
  }
}
