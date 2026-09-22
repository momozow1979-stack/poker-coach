import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gto_flop_strategy.dart';

/// 同梱アセットからソルバーのフロップ戦略を読み込む。
///
/// データがまだ無い／壊れている場合は空を返す（画面側は入り口ごと隠す）。
final gtoFlopStrategyProvider = FutureProvider<GtoFlopStrategy>((ref) async {
  try {
    final raw = await rootBundle.loadString(
      'assets/gto/solved_srp_btn_bb.json',
    );
    return GtoFlopStrategy.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } on Exception {
    return GtoFlopStrategy.empty;
  }
});
