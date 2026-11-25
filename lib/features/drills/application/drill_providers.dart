import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../range_chart/infrastructure/mock_range_repository.dart';
import '../../practice_table/domain/grading/decision_grader.dart';
import '../domain/bluff_drill_opponent.dart';
import '../domain/bluff_spot.dart';
import '../domain/equity_quiz.dart';
import '../domain/preflop_drill.dart';

/// ドリルの出題に使う乱数。テストでは種を固定して差し替える。
final drillRandomProvider = Provider<Random>((ref) => Random());

/// プリフロップ連続ドリルの出題役（アプリ同梱のレンジ表を答えにする）。
final preflopDrillGeneratorProvider = Provider<PreflopDrillGenerator>(
  (ref) => PreflopDrillGenerator(
    ranges: const MockRangeRepository(),
    random: ref.watch(drillRandomProvider),
  ),
);

/// 勝率クイズの出題役。
final equityQuizGeneratorProvider = Provider<EquityQuizGenerator>(
  (ref) => EquityQuizGenerator(random: ref.watch(drillRandomProvider)),
);

/// ブラフ練習の出題役。採点はこの練習専用の相手（[BluffDrillOpponent]）の
/// 打ち方で計算する。
final bluffSpotGeneratorProvider = Provider<BluffSpotGenerator>(
  (ref) => BluffSpotGenerator(
    opponent: const BluffDrillOpponent(),
    grader: const PracticeDecisionGrader(opponent: BluffDrillOpponent()),
    random: ref.watch(drillRandomProvider),
  ),
);
