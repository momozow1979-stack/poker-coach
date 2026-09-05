import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// プレイヤーが選べるアクション。
///
/// ベットサイズは種類ではなく [HandAction.sizeBb] で持つ。
/// 「ポットの33%」のような刻みを選ばせると、額を覚えていない人が
/// 入力できなくなるため、額は任意の数値として別に受け取る。
enum PokerActionType {
  fold('Fold', 'フォールド'),
  check('Check', 'チェック'),
  call('Call', 'コール'),
  bet('Bet', 'ベット'),
  raise('Raise', 'レイズ'),
  allIn('All-in', 'オールイン');

  const PokerActionType(this.label, this.description);

  final String label;
  final String description;

  /// 賭け金を増やすアクションか。
  bool get isAggressive => this == bet || this == raise || this == allIn;

  /// ラベルから復元する。保存済み JSON の読み戻しに使う。
  ///
  /// 以前はサイズを種類に埋め込んでいた（`Bet 33%` など）ため、
  /// 古い履歴が読めなくならないよう、旧ラベルも受け付ける。
  static PokerActionType fromLabel(String label) {
    for (final action in PokerActionType.values) {
      if (action.label == label) return action;
    }
    return switch (label) {
      'Limp' => call,
      'Bet 33%' || 'Bet 50%' || 'Bet 75%' || 'Bet Pot' => bet,
      '3Bet' || '4Bet' => raise,
      _ => check,
    };
  }
}

/// [PokerActionType] ごとの色・アイコン。
///
/// 色覚特性や白黒表示でも区別できるよう、アイコン（形）を必ず併用する
/// 前提のセットにしてある（`RangeAction` の既存方針と同じ考え方）。
/// 新しい色は増やさず、既存の [AppColors] のうち意味が重なるものを使う:
/// コール＝レンジ表の Call 色、ベット/レイズ/オールインは
/// レンジ表の Raise/3Bet/4Bet 色（段階が上がるほど攻撃的、という並びを流用）。
/// フォールド・チェックにはレンジ表側に対応する色が無いため、
/// 既存の中立色（textMuted / info）を使う。
extension PokerActionTypeVisuals on PokerActionType {
  Color get color => switch (this) {
    PokerActionType.fold => AppColors.textMuted,
    PokerActionType.check => AppColors.info,
    PokerActionType.call => AppColors.rangeCall,
    PokerActionType.bet => AppColors.rangeRaise,
    PokerActionType.raise => AppColors.rangeThreeBet,
    PokerActionType.allIn => AppColors.rangeFourBet,
  };

  IconData get icon => switch (this) {
    PokerActionType.fold => Icons.close_rounded,
    PokerActionType.check => Icons.remove_rounded,
    PokerActionType.call => Icons.compare_arrows_rounded,
    PokerActionType.bet => Icons.arrow_upward_rounded,
    PokerActionType.raise => Icons.trending_up_rounded,
    PokerActionType.allIn => Icons.bolt_rounded,
  };
}

/// 「誰が何をしたか」を表す 1 アクション。
class HandAction {
  const HandAction({required this.actor, required this.action, this.sizeBb});

  /// `hero` もしくはポジション名（`BB` など）。
  final String actor;
  final PokerActionType action;

  /// 任意。そのストリートで、その人が出した合計額（BB 単位）。
  ///
  /// レイズは「いくらまで上げたか」で持つ。分からなければ null のままでよい。
  final double? sizeBb;

  bool get isHero => actor == heroActor;

  /// 画面表示用のアクター名。JSON では `hero` のまま送る。
  String get actorLabel => isHero ? 'あなた' : actor;

  static const String heroActor = 'hero';

  HandAction copyWith({double? sizeBb}) =>
      HandAction(actor: actor, action: action, sizeBb: sizeBb ?? this.sizeBb);

  factory HandAction.fromJson(Map<String, dynamic> json) => HandAction(
    actor: json['actor'] as String? ?? heroActor,
    action: PokerActionType.fromLabel(json['action'] as String? ?? ''),
    sizeBb: (json['size_bb'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'actor': actor,
    'action': action.label,
    if (sizeBb != null) 'size_bb': sizeBb,
  };

  /// 画面に出す1行。JSON では [toJson] を使うので、ここは日本語でよい。
  @override
  String toString() => sizeBb == null
      ? '$actorLabel ${action.description}'
      : '$actorLabel ${action.description} ${formatBb(sizeBb!)}BB';

  /// 無駄な小数を出さずに BB 額を整える。
  static String formatBb(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
