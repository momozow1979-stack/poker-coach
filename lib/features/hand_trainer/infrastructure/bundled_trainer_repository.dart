import '../domain/trainer_repository.dart';
import '../domain/trainer_scenario.dart';
import 'scenarios/bb_middle_pair_defense.dart';
import 'scenarios/bb_threebet_paired_board.dart';
import 'scenarios/btn_ak_monotone.dart';
import 'scenarios/btn_vs_station.dart';
import 'scenarios/btn_aq_dry_board.dart';
import 'scenarios/co_draw_wet_board.dart';
import 'scenarios/co_short_stack_plan.dart';

/// アプリ同梱のシナリオを返すリポジトリ。
///
/// 将来 Edge Function で動的に生成する実装を足すときは、
/// [TrainerScenarioRepository] の別実装を作って差し替える。
class BundledTrainerRepository implements TrainerScenarioRepository {
  const BundledTrainerRepository();

  static final List<TrainerScenario> _scenarios = List.unmodifiable([
    btnAqDryBoard,
    bbMiddlePairDefense,
    coDrawWetBoard,
    btnAkMonotone,
    bbThreeBetPairedBoard,
    coShortStackPlan,
    btnVsStation,
  ]);

  @override
  List<TrainerScenario> all() => _scenarios;

  @override
  TrainerScenario? byId(String id) {
    for (final scenario in _scenarios) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }
}
