import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/position.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;

/// 1 ハンドで起きたことを表すイベント。
///
/// ライブプレイもリプレイも、同じイベント列から
/// [PracticeHandState.replay] で状態を再現する。両方の画面を
/// 別々のロジックで動かすと食い違う恐れがあるため、必ずここを経由させる。
sealed class PracticeEvent {
  const PracticeEvent();
}

/// ハンドの開始。ポジション・スタック・双方の手札が決まった瞬間。
class HandDealt extends PracticeEvent {
  const HandDealt({
    required this.tableType,
    required this.heroPosition,
    required this.villainPosition,
    required this.heroCards,
    required this.villainCards,
    required this.startingStackBb,
  });

  final TableType tableType;
  final Position heroPosition;
  final Position villainPosition;
  final List<PlayingCard> heroCards;
  final List<PlayingCard> villainCards;
  final double startingStackBb;
}

/// そのストリートのボードカードが開いた。
class BoardDealt extends PracticeEvent {
  const BoardDealt({required this.street, required this.cards});

  final Street street;
  final List<PlayingCard> cards;
}

/// どちらかが行動した。
class ActionOccurred extends PracticeEvent {
  const ActionOccurred({
    required this.street,
    required this.actor,
    required this.action,
    this.sizeBb,
  });

  final Street street;
  final Actor actor;
  final PokerActionType action;

  /// そのストリートで、その人が出した合計額（BB）。[HandAction.sizeBb] と同じ考え方。
  final double? sizeBb;
}

/// ハンドが終わった。
class HandFinished extends PracticeEvent {
  const HandFinished({
    required this.endedByFold,
    required this.potBb,
    this.winner,
  });

  final bool endedByFold;

  /// 最終ポット。
  final double potBb;

  /// 勝者。ショーダウンで分けた場合は null。
  final Actor? winner;
}
