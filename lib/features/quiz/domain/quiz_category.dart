/// クイズのカテゴリ。学習統計と苦手分野の算出単位でもある。
enum QuizCategory {
  preflop('preflop', 'プリフロップ', 'プリ'),
  flop('flop', 'フロップ', 'フロ'),
  turn('turn', 'ターン', 'ターン'),
  river('river', 'リバー', 'リバー'),
  position('position', 'ポジション', 'ポジ'),
  betSizing('bet_sizing', 'ベットサイズ', 'サイズ'),
  potOdds('pot_odds', 'ポットオッズ', 'オッズ'),
  valueBluff('value_bluff', 'バリュー / ブラフ', 'V/B'),
  gto('gto', 'GTO', 'GTO'),
  exploit('exploit', 'エクスプロイト', 'EXP'),
  terminology('terminology', '用語', '用語');

  const QuizCategory(this.id, this.label, this.shortLabel);

  final String id;
  final String label;

  /// レーダーチャートの軸など、幅の取れない場所で使う短縮名。
  final String shortLabel;

  static QuizCategory fromId(String id) =>
      QuizCategory.values.firstWhere((category) => category.id == id);
}

/// 出題難易度。
enum QuizDifficulty {
  beginner(1, '初級'),
  intermediate(2, '中級'),
  advanced(3, '上級');

  const QuizDifficulty(this.level, this.label);

  final int level;
  final String label;
}
