import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../range_chart/infrastructure/mock_range_repository.dart';
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
