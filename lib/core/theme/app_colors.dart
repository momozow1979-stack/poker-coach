import 'package:flutter/material.dart';

/// アプリ全体のカラーパレット。
///
/// ベースは引き続き Dark Navy（学習アプリらしい清潔感を保つ）だが、
/// カジュアル層に「素っ気ない」と感じさせないよう、報酬・達成を示す
/// 場面（連続記録・レベル・正解）にだけ暖色のアクセント（ゴールド/コーラル）を
/// 足している。カード面もフラット一辺倒ではなく、グラデーションと
/// ごく薄いグロー（影）を持たせて奥行きを出す。
abstract final class AppColors {
  /// 画面の一番下地。
  static const Color background = Color(0xFF0B111C);

  /// カード / パネルの背景。背景より少し明るいダークグレー。
  static const Color surface = Color(0xFF141C2B);

  /// カードの中に重ねるさらに一段明るい面。
  static const Color surfaceHigh = Color(0xFF1D2739);

  /// 境界線。
  static const Color border = Color(0xFF27334A);

  /// メインのアクセント（Green 系）。ボタンや選択状態など「操作」に使う。
  static const Color accent = Color(0xFF2ED3A0);
  static const Color accentDark = Color(0xFF14A87C);

  /// サブのアクセント（Blue 系）。
  static const Color info = Color(0xFF4C8DFF);

  /// 報酬・達成のアクセント（Gold 系）。連続記録・レベルアップ・
  /// 正解の演出など「うれしい瞬間」だけに使う、暖色の差し色。
  static const Color reward = Color(0xFFF5B94D);
  static const Color rewardDark = Color(0xFFD9902A);

  /// 応援・元気づけのアクセント（Coral/Pink 系）。ホーム画面のコーチ
  /// メッセージなど、温かみを出したい場面のワンポイントに使う。
  static const Color warmAccent = Color(0xFFFF7D6B);

  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFFA6B1C4);
  static const Color textMuted = Color(0xFF6E7B92);

  static const Color success = Color(0xFF2ED3A0);
  static const Color warning = Color(0xFFF2B544);
  static const Color danger = Color(0xFFF2685C);

  /// レンジ表のアクション色。
  /// 色だけに頼らないよう、必ず記号ラベルと併用すること。
  static const Color rangeRaise = Color(0xFFE0655B);
  static const Color rangeCall = Color(0xFF3FA96F);
  static const Color rangeFold = Color(0xFF2A3448);
  static const Color rangeThreeBet = Color(0xFF8F6BE0);
  static const Color rangeFourBet = Color(0xFFC04A8A);
  static const Color rangeMixed = Color(0xFFD9A441);

  /// ホームのヘッダーやレベルカードなど「主役」の面に使うグラデーション。
  /// 単色のフラット面より、遠目にも華やかに見える。
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17324A), Color(0xFF0F1B2E)],
  );

  /// 連続記録・達成バッジなど、報酬を示す面に使う暖色グラデーション。
  static const LinearGradient rewardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5B94D), Color(0xFFE07A3F)],
  );

  /// カードにごく薄く落とす影。フラットな面に最小限の奥行きを足す。
  static List<BoxShadow> cardGlow({Color? color}) => [
    BoxShadow(
      color: (color ?? Colors.black).withValues(alpha: 0.28),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
