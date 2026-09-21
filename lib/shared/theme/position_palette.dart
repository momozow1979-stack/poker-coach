import 'package:flutter/material.dart';

import '../models/position.dart';

/// ポジションごとの色を、アプリ全体で統一するための唯一の定義。
///
/// レンジ表（集約色分け）でも、クイズ/レビューの卓図でも、必ずここを使う。
/// 「自分 / 相手」は色では区別せず（同じポジションなら同じ色）、文字で区別する。
Color positionColor(Position position) => switch (position) {
  // 6MAX の6席（配色A・くっきり分散）。COとBTNは別系統で表でも見分けやすい。
  Position.utg => const Color(0xFFE11D48), // ローズ
  Position.hj => const Color(0xFFF59E0B), // アンバー
  Position.co => const Color(0xFF7C3AED), // バイオレット
  Position.btn => const Color(0xFF059669), // エメラルド
  Position.sb => const Color(0xFF2563EB), // ブルー
  Position.bb => const Color(0xFF64748B), // スレート
  // 9MAX 専用の3席（上の6色とぶつからない色）。
  Position.utg1 => const Color(0xFFDB2777), // ピンク
  Position.mp => const Color(0xFF0891B2), // シアン
  Position.lj => const Color(0xFF9A6700), // オリーブ
};

/// 卓図で「自分 / 相手」を示すラベルの文字色（役割で色を変えず統一する）。
const Color seatRoleLabelColor = Color(0xFF111827);
