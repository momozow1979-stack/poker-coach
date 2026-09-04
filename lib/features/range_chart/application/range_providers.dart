import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/position.dart';
import '../../../shared/models/table_type.dart';
import '../domain/range_entry.dart';
import '../domain/range_repository.dart';
import '../domain/range_spot.dart';
import '../infrastructure/mock_range_repository.dart';
import '../infrastructure/range_definitions.dart';

final rangeRepositoryProvider = Provider<RangeRepository>(
  (ref) => const MockRangeRepository(),
);

/// レンジ表で選択中のテーブル人数。
class TableTypeSelection extends Notifier<TableType> {
  @override
  TableType build() => TableType.sixMax;

  void select(TableType tableType) => state = tableType;
}

final selectedTableTypeProvider =
    NotifierProvider<TableTypeSelection, TableType>(TableTypeSelection.new);

/// レンジ表で選択中のポジション。
class PositionSelection extends Notifier<Position> {
  @override
  Position build() => Position.btn;

  void select(Position position) => state = position;
}

final selectedPositionProvider = NotifierProvider<PositionSelection, Position>(
  PositionSelection.new,
);

/// レンジ表で選択中のシチュエーション（オープン / vsOpen）。
///
/// テーブル人数・ポジションを切り替えたとき、選択中のシチュエーションが
/// そのポジションに存在しなければ、利用可能な先頭のシチュエーションへ戻す。
class SituationSelection extends Notifier<RangeSituation?> {
  @override
  RangeSituation? build() => null;

  void select(RangeSituation situation) => state = situation;

  /// [tableType] / [position] に存在しないシチュエーションを選んでいたら補正する。
  void resetIfUnavailable(TableType tableType, Position position) {
    final available = RangeDefinitions.situationsFor(tableType, position);
    if (state != null && !available.contains(state)) {
      state = null;
    }
  }
}

final selectedSituationProvider =
    NotifierProvider<SituationSelection, RangeSituation?>(
      SituationSelection.new,
    );

/// 現在選択中のポジションで切り替えられるシチュエーション一覧。
final availableSituationsProvider = Provider<List<RangeSituation>>((ref) {
  final tableType = ref.watch(selectedTableTypeProvider);
  final position = ref.watch(selectedPositionProvider);
  return RangeDefinitions.situationsFor(tableType, position);
});

/// 現在の選択に対応するレンジ表。
final selectedRangeChartProvider = Provider<RangeChart?>((ref) {
  final tableType = ref.watch(selectedTableTypeProvider);
  final position = ref.watch(selectedPositionProvider);
  final situation = ref.watch(selectedSituationProvider);
  return ref
      .watch(rangeRepositoryProvider)
      .chartFor(tableType, position, situation: situation);
});

/// スポット ID を指定して取得する（クイズ解説からのリンク用）。
final rangeChartByIdProvider = Provider.family<RangeChart?, String>((
  ref,
  spotId,
) {
  return ref.watch(rangeRepositoryProvider).chartById(spotId);
});
