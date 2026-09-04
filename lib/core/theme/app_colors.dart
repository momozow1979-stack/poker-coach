import 'package:flutter/material.dart';

/// アプリ全体のカラーパレット。
///
/// ライトテーマ（黒背景を避けたいというフィードバックを受けて採用）。
/// 白いカードが薄いスレート地の上に浮くレイアウトにし、報酬・達成を示す
/// 場面（連続記録・レベル・正解）にだけ暖色のアクセント（ゴールド/コーラル）を
/// 足している。アクセント色は白背景の上でも読める濃さに調整済み
/// （GitHub Primer のライトテーマ配色を参考に、本文サイズでも
/// コントラスト比 4.5:1 以上を確保）。
abstract final class AppColors {
  /// 画面の一番下地。白より少しだけ沈めて、白いカードとの境目を作る。
  static const Color background = Color(0xFFF1F5F9);

  /// カード / パネルの背景。
  static const Color surface = Color(0xFFFFFFFF);

  /// カードの中に重ねる、もう一段沈んだ面（進捗バーの下地・入力欄など）。
  static const Color surfaceHigh = Color(0xFFE2E8F0);

  /// 境界線。
  static const Color border = Color(0xFFE2E8F0);

  /// メインのアクセント（Green 系）。ボタンや選択状態など「操作」に使う。
  /// 白背景の上でも文字色として読めるよう、彩度を保ったまま暗めに調整。
  static const Color accent = Color(0xFF1A7F37);
  static const Color accentDark = Color(0xFF116329);

  /// アクセント塗り（[accent] 等）の上に乗せる文字色。
  static const Color onAccent = Colors.white;

  /// サブのアクセント（Blue 系）。
  static const Color info = Color(0xFF0969DA);

  /// 報酬・達成のアクセント（Gold 系）。連続記録・レベルアップ・
  /// 正解の演出など「うれしい瞬間」だけに使う、暖色の差し色。
  /// 常に専用の濃い文字色（下記グラデーション参照）と組みで使うため、
  /// 明るいままにしている。
  static const Color reward = Color(0xFFF5B94D);
  static const Color rewardDark = Color(0xFFD9902A);

  /// 応援・元気づけのアクセント（Coral/Pink 系）。クイズ正解時の紙吹雪など、
  /// 単発の演出だけに使う（本文の文字色には使わない）。
  static const Color warmAccent = Color(0xFFFF7D6B);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);

  static const Color success = accent;
  static const Color warning = Color(0xFF9A6700);
  static const Color danger = Color(0xFFD1242F);

  /// レンジ表のアクション色。
  /// 色だけに頼らないよう、必ず記号ラベルと併用すること。
  static const Color rangeRaise = Color(0xFFE0655B);
  static const Color rangeCall = Color(0xFF3FA96F);
  static const Color rangeFold = surfaceHigh;
  static const Color rangeThreeBet = Color(0xFF8F6BE0);
  static const Color rangeFourBet = Color(0xFFC04A8A);
  static const Color rangeMixed = Color(0xFFD9A441);

  /// ホームのヘッダーやレベルカードなど「主役」の面に使うグラデーション。
  /// 白一色より奥行きが出るよう、アクセントをごく薄く滲ませた白。
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE7F5EC), Color(0xFFFFFFFF)],
  );

  /// 連続記録・達成バッジなど、報酬を示す面に使う暖色グラデーション。
  static const LinearGradient rewardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5B94D), Color(0xFFE07A3F)],
  );

  /// カードにごく薄く落とす影。フラットな面に最小限の奥行きを足す。
  /// 白背景の上では暗い影が強く出すぎるため、ダークテーマ時より薄くしている。
  static List<BoxShadow> cardGlow({Color? color}) => [
    BoxShadow(
      color: (color ?? Colors.black).withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
