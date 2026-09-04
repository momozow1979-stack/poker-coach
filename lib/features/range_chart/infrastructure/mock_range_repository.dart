import '../../../shared/models/position.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/models/table_type.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';
import '../domain/range_notation.dart';
import '../domain/range_repository.dart';
import '../domain/range_spot.dart';
import 'range_definitions.dart';

/// アプリ同梱データからレンジ表を組み立てるリポジトリ。
///
/// Phase 5 で Supabase の `range_spots` / `range_actions` に置き換える。
class MockRangeRepository implements RangeRepository {
  const MockRangeRepository();

  @override
  List<RangeSpot> spotsFor(TableType tableType) => [
    for (final definition in RangeDefinitions.all)
      if (definition.spot.tableType == tableType) definition.spot,
  ];

  @override
  RangeChart? chartFor(
    TableType tableType,
    Position position, {
    RangeSituation? situation,
  }) {
    final definition = RangeDefinitions.find(tableType, position, situation);
    if (definition == null) return null;
    return _chartFrom(definition);
  }

  @override
  RangeChart? chartById(String spotId) {
    for (final definition in RangeDefinitions.all) {
      if (definition.spot.id == spotId) {
        return _chartFrom(definition);
      }
    }
    return null;
  }

  RangeChart _chartFrom(RangeDefinition definition) {
    final actionByHand = <String, RangeAction>{};
    for (final entry in definition.notationByAction.entries) {
      for (final hand in RangeNotation.expand(entry.value)) {
        actionByHand[hand] = entry.key;
      }
    }

    final blendByHand = <String, RangeActionBlend>{};
    for (final group in definition.mixedGroups) {
      final blend = RangeActionBlend(
        primary: group.primary,
        primaryShare: group.primaryShare,
        secondary: group.secondary,
      );
      for (final hand in RangeNotation.expand(group.notation)) {
        actionByHand[hand] = RangeAction.mixed;
        blendByHand[hand] = blend;
      }
    }

    final entries = <String, RangeEntry>{};
    for (final hand in StartingHand.all) {
      final action = actionByHand[hand.code] ?? RangeAction.fold;
      entries[hand.code] = RangeEntry(
        hand: hand,
        action: action,
        frequency: action == RangeAction.mixed ? 0.5 : 1,
        blend: action == RangeAction.mixed ? blendByHand[hand.code] : null,
      );
    }

    return RangeChart(spot: definition.spot, entries: entries);
  }
}
