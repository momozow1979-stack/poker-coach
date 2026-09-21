import 'package:flutter/material.dart';

import '../models/position.dart';

/// ポジションごとの色を、アプリ全体で統一するための唯一の定義。
///
/// レンジ表（集約色分け）でも、クイズ/レビューの卓図でも、必ずここを使う。
/// 「自分 / 相手」は色では区別せず（同じポジションなら同じ色）、文字で区別する。
Color positionColor(Position position) => switch (position) {
  Position.utg => const Color(0xFFC04A8A), // マゼンタ
  Position.utg1 => const Color(0xFF8F6BE0), // パープル
  Position.mp => const Color(0xFFD1242F), // レッド
  Position.lj => const Color(0xFFE0655B), // コーラル
  Position.hj => const Color(0xFFE1922E), // アンバー
  Position.co => const Color(0xFF1A7F37), // グリーン
  Position.btn => const Color(0xFF0E9F6E), // ティール
  Position.sb => const Color(0xFF0969DA), // ブルー
  Position.bb => const Color(0xFF64748B), // スレート
};

/// 卓図で「自分 / 相手」を示すラベルの文字色（役割で色を変えず統一する）。
const Color seatRoleLabelColor = Color(0xFF111827);
