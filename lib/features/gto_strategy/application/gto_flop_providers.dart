import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gto_flop_strategy.dart';

/// 同梱アセットからソルバーのフロップ戦略を読み込む（BTN vs BB固定）。
///
/// データがまだ無い／壊れている場合は空を返す（画面側は入り口ごと隠す）。
final gtoFlopStrategyProvider = FutureProvider<GtoFlopStrategy>((ref) async {
  try {
    final raw = await rootBundle.loadString(
      'assets/gto/solved_srp_btn_bb.json',
    );
    return GtoFlopStrategy.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return GtoFlopStrategy.empty;
  }
});

/// 既知の全マッチアップID（`solver/solve_srp_btn_bb.py` の `MATCHUPS` と
/// 同じ集合）。本番計算・統合が終わって `assets/gto/solved_srp_<id>.json` が
/// 同梱された分だけ、[gtoMatchupCatalogProvider] の選択肢として現れる。
const matchupIds = [
  'btn_bb',
  'hj_utg_6max',
  'co_hj_6max',
  'btn_co',
  'sb_btn',
  'utg1_utg_9max',
  'mp_utg1_9max',
  'lj_mp_9max',
  'hj_lj_9max',
  'co_hj_9max',
];

/// 同梱されている全マッチアップの戦略データ一覧（本番計算・統合が
/// 終わったものだけ）。GTOフロップ戦略ページのマッチアップ選択に使う。
final gtoMatchupCatalogProvider = FutureProvider<List<GtoFlopStrategy>>((
  ref,
) async {
  final result = <GtoFlopStrategy>[];
  for (final id in matchupIds) {
    try {
      final raw = await rootBundle.loadString('assets/gto/solved_srp_$id.json');
      result.add(
        GtoFlopStrategy.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    } catch (_) {
      // まだ本番計算・統合が終わっていないマッチアップ。選択肢に出さない。
      // アセット未同梱時に rootBundle.loadString が投げるのは Exception では
      // なく FlutterError（Error系）なので、on Exception では捕まらない。
    }
  }
  return result;
});
