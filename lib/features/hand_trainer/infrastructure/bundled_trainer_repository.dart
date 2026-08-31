import '../domain/trainer_repository.dart';
import '../domain/trainer_scenario.dart';
import 'scenarios/btn_aq_dry_board.dart';

/// アプリ同梱のシナリオを返すリポジトリ。
///
/// 将来 Edge Function で動的に生成する実装を足すときは、
/// [TrainerScenarioRepository] の別実装を作って差し替える。
class BundledTrainerRepository implements TrainerScenarioRepository {
  const BundledTrainerRepository();

  static final List<TrainerScenario> _scenarios = List.unmodifiable([
    btnAqDryBoard,
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
