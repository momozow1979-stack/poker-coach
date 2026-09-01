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
