import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';
import '../../quiz/domain/learning_stage.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../../quiz/domain/quiz_category.dart';
import '../../quiz/infrastructure/quiz_bank.dart';
import '../domain/growth_rank.dart';
import 'learning_providers.dart';

/// 1ステージ分の「問題数の進捗」と「正解率」。
///
/// 進捗バーは問題数（＝そのステージの問題を何問こなしたか）で出す。
/// 正解率はテキストのみ。両方が満点（＝全問を正解済み）になると Clear。
class StageProgress {
  const StageProgress({
    required this.stage,
    required this.attempted,
    required this.solved,
    required this.total,
  });

  final LearningStage stage;

  /// そのステージで一度でも回答した問題数（重複なし）。
  final int attempted;

  /// 最新の回答が正解だった問題数（重複なし）。
  final int solved;

  /// そのステージの総問題数。
  final int total;

  /// 進捗バー = 問題数の進捗（こなした問題 / 総問題）。
  double get progress => total == 0 ? 0 : (attempted / total).clamp(0.0, 1.0);

  /// 正解率（テキスト表示用）＝ 正解した問題 / 回答した問題。
  double get accuracy => attempted == 0 ? 0 : solved / attempted;

  /// 問題数の進捗 × 正解率 = 100%（＝全問を正解済み）で Clear。
  bool get cleared => total > 0 && solved >= total;
}

/// 学習の進捗まとめ（ステージ別＋総ユニーク正解数）。
class LearningProgress {
  const LearningProgress({required this.stages, required this.totalSolved});

  final Map<LearningStage, StageProgress> stages;

  /// 全カテゴリ合計の「最新回答が正解だった問題数（重複なし）」。レベル判定に使う。
  final int totalSolved;

  StageProgress of(LearningStage stage) =>
      stages[stage] ??
      StageProgress(stage: stage, attempted: 0, solved: 0, total: 0);
}

LearningProgress _compute(List<QuizAttempt> attempts) {
  // 問題IDごとの最新の回答。
  final latest = <String, QuizAttempt>{};
  for (final a in attempts) {
    final current = latest[a.quizId];
    if (current == null || a.answeredAt.isAfter(current.answeredAt)) {
      latest[a.quizId] = a;
    }
  }
  final attemptedByCat = <QuizCategory, int>{};
  final solvedByCat = <QuizCategory, int>{};
  for (final a in latest.values) {
    attemptedByCat[a.category] = (attemptedByCat[a.category] ?? 0) + 1;
    if (a.isCorrect) {
      solvedByCat[a.category] = (solvedByCat[a.category] ?? 0) + 1;
    }
  }
  final totalByCat = {
    for (final c in QuizCategory.values) c: QuizBank.byCategory(c).length,
  };

  final stages = <LearningStage, StageProgress>{};
  var totalSolved = 0;
  for (final stage in LearningStage.values) {
    var attempted = 0, solved = 0, total = 0;
    for (final c in stage.categories) {
      attempted += attemptedByCat[c] ?? 0;
      solved += solvedByCat[c] ?? 0;
      total += totalByCat[c] ?? 0;
    }
    stages[stage] = StageProgress(
      stage: stage,
      attempted: attempted,
      solved: solved,
      total: total,
    );
    totalSolved += solved;
  }
  return LearningProgress(stages: stages, totalSolved: totalSolved);
}

/// 学習履歴から算出する進捗まとめ。
final learningProgressProvider = Provider<LearningProgress>((ref) {
  final attempts = ref.watch(learningStoreProvider).attempts;
  return _compute(attempts);
});

// ---- レンジ表暗記ドリルのクリア記録（端末に永続化）----

const _drillClearsKey = 'drill_clears';

/// レンジ表暗記ドリルで「満点クリア」した状況（`'open'` / `'vsopen'`）の集合。
class DrillProgressStore extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return const {};
  }

  KeyValueStore get _kv => ref.read(keyValueStoreProvider);

  Future<void> _load() async {
    final saved = await _kv.getStringList(_drillClearsKey);
    if (saved != null && ref.mounted) state = saved.toSet();
  }

  /// [key]（`'open'` / `'vsopen'`）をクリア済みとして記録する。
  Future<void> markCleared(String key) async {
    if (state.contains(key)) return;
    state = {...state, key};
    await _kv.setStringList(_drillClearsKey, state.toList());
  }
}

final drillProgressStoreProvider =
    NotifierProvider<DrillProgressStore, Set<String>>(DrillProgressStore.new);

/// 現在の上達ランク（見習い〜名人）。座学のユニーク正解数＋レンジ暗記クリアで決まる。
final growthRankProvider = Provider<GrowthRank>((ref) {
  final progress = ref.watch(learningProgressProvider);
  final clears = ref.watch(drillProgressStoreProvider);
  return GrowthRank.forProgress(
    uniqueSolved: progress.totalSolved,
    openDrillCleared: clears.contains('open'),
    vsOpenDrillCleared: clears.contains('vsopen'),
  );
});
