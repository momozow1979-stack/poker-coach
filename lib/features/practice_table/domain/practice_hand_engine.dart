import '../../../shared/models/hand_strength.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import 'practice_deck.dart';
import 'practice_event.dart';
import 'practice_hand_state.dart';

/// v1 の固定シナリオ: ヒーローが BTN（オープンする側）、
/// ヴィラン（AI）が BB（ディフェンドする側）。
///
/// 他のポジションは UTG〜CO がすでに畳んだ想定（6max のオープン練習として
/// 最も頻度の高い場面）。将来ポジションを増やすなら、ここを
/// 引数化すればよい設計にしてある。
const practiceTableType = TableType.sixMax;
const practiceHeroPosition = Position.btn;
const practiceVillainPosition = Position.bb;
const practiceStartingStackBb = 100.0;

/// 1 ハンドの進行を管理する。イベントを積み上げていくだけで、
/// 状態そのものは常に [PracticeHandState.replay] から導く
/// （二重に状態を持つと、画面とイベントログが食い違う恐れがあるため）。
class PracticeHandEngine {
  PracticeHandEngine({PracticeDeck? deck}) : _deck = deck ?? PracticeDeck() {
    _start();
  }

  final PracticeDeck _deck;
  final List<PracticeEvent> _events = [];

  List<PracticeEvent> get events => List.unmodifiable(_events);

  PracticeHandState get state => PracticeHandState.replay(_events);

  void _start() {
    final heroCards = _deck.draw(2);
    final villainCards = _deck.draw(2);
    _events.add(
      HandDealt(
        tableType: practiceTableType,
        heroPosition: practiceHeroPosition,
        villainPosition: practiceVillainPosition,
        heroCards: heroCards,
        villainCards: villainCards,
        startingStackBb: practiceStartingStackBb,
      ),
    );
  }

  /// [actor] が [action] を選ぶ。ベット / レイズ / コールなら [sizeBb] に
  /// 「このストリートで揃える額」を渡す（[HandAction.sizeBb] と同じ考え方）。
  ///
  /// ラウンドが閉じたら、次のボードカードを配るか（フロップ以降がまだ
  /// 残っていれば）、リバーまで終わっていればショーダウンを判定して
  /// 自動的にイベントを積む。呼び出し側は「次に誰の番か」だけ見ればよい。
  void apply(Actor actor, PokerActionType action, {double? sizeBb}) {
    final before = state;
    if (before.isOver || before.actorToAct != actor) {
      throw StateError('$actor の番ではありません（現在: ${before.actorToAct}）');
    }
    _events.add(
      ActionOccurred(
        street: before.street,
        actor: actor,
        action: action,
        sizeBb: sizeBb,
      ),
    );
    _advanceIfNeeded();
  }

  void _advanceIfNeeded() {
    final after = state;
    if (after.isOver) {
      // フォールドで終わった場合、[PracticeHandState] はここまでの
      // ActionOccurred（fold）だけから終了を判定できるが、リプレイ画面が
      // 「フォールドの後に何か別のイベントを待つ」ことがないよう、
      // 終端イベントを明示的に積んでおく。
      if (after.endedByFold) {
        _events.add(
          HandFinished(
            endedByFold: true,
            potBb: after.pot,
            winner: after.winner,
          ),
        );
      }
      return;
    }
    if (!after.isAwaitingNextStreet) return;

    final next = _nextStreet(after.street);
    if (next == null) {
      _finishAtShowdown(after);
      return;
    }
    _events.add(
      BoardDealt(street: next, cards: _deck.draw(_boardCountFor(next))),
    );
  }

  void _finishAtShowdown(PracticeHandState atRiver) {
    final heroBest = HandStrength.best([
      ...atRiver.heroCards,
      ...atRiver.board,
    ]);
    final villainBest = HandStrength.best([
      ...atRiver.villainCards,
      ...atRiver.board,
    ]);
    final result = heroBest.compareTo(villainBest);
    _events.add(
      HandFinished(
        endedByFold: false,
        potBb: atRiver.pot,
        winner: result == 0 ? null : (result > 0 ? Actor.hero : Actor.villain),
      ),
    );
  }

  static Street? _nextStreet(Street current) => switch (current) {
    Street.preflop => Street.flop,
    Street.flop => Street.turn,
    Street.turn => Street.river,
    Street.river => null,
  };

  static int _boardCountFor(Street street) => switch (street) {
    Street.preflop => 0,
    Street.flop => 3,
    Street.turn => 1,
    Street.river => 1,
  };
}
