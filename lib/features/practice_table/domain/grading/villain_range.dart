import '../../../../shared/models/playing_card.dart';
import '../../../hand_review/domain/hand_flow.dart' show Actor;
import '../practice_event.dart';
import '../practice_hand_state.dart';
import '../practice_opponent.dart';

/// ヒーローから見て、相手（AI）が持っている可能性のある手札。
///
/// 相手の打ち方（[PracticeOpponent]）はこのアプリ自身のコードなので、
/// 「もしこの手札だったら、ここまで同じ行動を取ったか」を 1 通りずつ
/// 実際に試せる。ここまでの行動と食い違う手札を除いたものが、
/// ヒーローに見えている情報だけから正確に言える相手の範囲になる。
///
/// **実際の相手の手札は使わない**（使うと結果論の採点になる）。実際の手札も
/// 候補の 1 つとして他と同じ重みで含まれるだけ。
abstract final class VillainRange {
  /// [events] は採点したい判断の直前まで（先頭は [HandDealt]）。
  static List<List<PlayingCard>> consistentCombos({
    required List<PracticeEvent> events,
    required PracticeOpponent opponent,
  }) {
    final dealt = events.first as HandDealt;
    final known = <PlayingCard>{...dealt.heroCards};
    for (final event in events) {
      if (event is BoardDealt) known.addAll(event.cards);
    }
    final deck = [
      for (final card in PlayingCard.fullDeck)
        if (!known.contains(card)) card,
    ];

    final villainActionIndexes = [
      for (var i = 0; i < events.length; i++)
        if (events[i] case ActionOccurred(actor: Actor.villain)) i,
    ];

    final result = <List<PlayingCard>>[];
    for (var a = 0; a < deck.length - 1; a++) {
      for (var b = a + 1; b < deck.length; b++) {
        final combo = [deck[a], deck[b]];
        final replaced = withVillainCards(events, combo);
        var consistent = true;
        for (final index in villainActionIndexes) {
          final observed = events[index] as ActionOccurred;
          final before = PracticeHandState.replay(replaced.sublist(0, index));
          final decision = opponent.decide(before);
          if (decision.action != observed.action ||
              !_sameSize(decision.sizeBb, observed.sizeBb)) {
            consistent = false;
            break;
          }
        }
        if (consistent) result.add(combo);
      }
    }
    return result;
  }

  /// 相手の手札だけを [combo] に差し替えたイベント列。
  static List<PracticeEvent> withVillainCards(
    List<PracticeEvent> events,
    List<PlayingCard> combo,
  ) {
    final dealt = events.first as HandDealt;
    return [
      HandDealt(
        tableType: dealt.tableType,
        heroPosition: dealt.heroPosition,
        villainPosition: dealt.villainPosition,
        heroCards: dealt.heroCards,
        villainCards: combo,
        startingStackBb: dealt.startingStackBb,
      ),
      ...events.skip(1),
    ];
  }

  static bool _sameSize(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() < 1e-6;
  }
}
