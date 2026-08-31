import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trainer_repository.dart';
import '../domain/trainer_scenario.dart';
import '../domain/trainer_session.dart';
import '../infrastructure/bundled_trainer_repository.dart';

final trainerRepositoryProvider = Provider<TrainerScenarioRepository>(
  (ref) => const BundledTrainerRepository(),
);

/// 一覧に出すシナリオすべて。
final trainerScenariosProvider = Provider<List<TrainerScenario>>(
  (ref) => ref.watch(trainerRepositoryProvider).all(),
);

/// ID 指定で 1 本取る。見つからなければ null。
final trainerScenarioProvider = Provider.family<TrainerScenario?, String>(
  (ref, id) => ref.watch(trainerRepositoryProvider).byId(id),
);

/// プレイ中のシナリオ 1 本。null は「まだ始めていない」。
///
/// 同時に 1 本しか遊ばないので、family ではなく単一の状態で持つ。
class TrainerSessionController extends Notifier<TrainerSession?> {
  @override
  TrainerSession? build() => null;

  /// [scenarioId] のシナリオを最初から始める。
  ///
  /// すでに同じシナリオを進めている場合は、その進行を保つ。
  /// 画面を作り直すたびに最初へ戻ってしまうのを防ぐため。
  void start(String scenarioId) {
    if (state?.scenario.id == scenarioId) return;
    final scenario = ref.read(trainerRepositoryProvider).byId(scenarioId);
    state = scenario == null ? null : TrainerSession(scenario: scenario);
  }

  void answer(String optionId) {
    final session = state;
    if (session == null) return;
    state = session.answer(optionId);
  }

  void next() {
    final session = state;
    if (session == null) return;
    state = session.next();
  }

  void restart() {
    final session = state;
    if (session == null) return;
    state = session.restart();
  }

  void clear() => state = null;
}

final trainerSessionProvider =
    NotifierProvider<TrainerSessionController, TrainerSession?>(
      TrainerSessionController.new,
    );
