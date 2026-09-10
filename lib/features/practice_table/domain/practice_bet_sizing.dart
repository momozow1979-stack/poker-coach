import '../../../shared/models/street.dart';

/// ベット / レイズの額を、任意入力ではなくプリセットから選ばせる。
///
/// プリフロップのオープンは「ポットの何%」では小さすぎて実戦的でない
/// （ブラインドしか入っていないため）ので、BB 倍率のプリセットを使う。
/// フロップ以降はポット割合のプリセット（練習用の目安であり、
/// ソルバー検証済みの数値ではない — 捏造防止のため、画面側でも
/// 「目安」であることを明記すること）。
abstract final class PracticeBetSizing {
  /// プリフロップでの、最初のオープンレイズの倍率（BB）。
  static const List<double> openRaiseMultiples = [2.2, 2.5, 3.0];

  /// フロップ以降のベット / レイズの、ポットに対する割合プリセット。
  static const List<double> potFractionPresets = [0.33, 0.66, 1.0];

  /// プリフロップの 3bet 以降（オープンへの再レイズ）のポット倍率。
  ///
  /// 「相手の額の何倍まで上げるか」という考え方が実戦に近いため、
  /// ポット割合ではなく、直前のベット額に対する倍率で持つ。
  static const List<double> reraiseMultiples = [2.5, 3.0];

  /// [street] とポット・直前のベット額から、具体的な BB 額の候補を作る。
  ///
  /// [potBb] はこの行動を選ぶ直前のポット、[facingBb] は直面している
  /// ベット額（フォールドしないなら最低でもこの額は払う必要がある）。
  static List<double> presetsFor({
    required Street street,
    required double potBb,
    required double facingBb,
  }) {
    if (street == Street.preflop && facingBb <= 1.0) {
      // 誰もレイズしていない（ブラインドのみ）: オープンサイズ。
      return openRaiseMultiples;
    }
    if (street == Street.preflop) {
      // 誰かがレイズ済み: その額の倍率で 3bet/4bet サイズを作る。
      return [for (final m in reraiseMultiples) (facingBb * m).roundToDouble()];
    }
    if (facingBb <= 0) {
      // 誰も賭けていない: このストリートで揃える額 = ポット割合そのもの。
      return [
        for (final fraction in potFractionPresets)
          _roundToQuarter(potBb * fraction),
      ];
    }
    // 賭けに直面している: 「コールした後にできるポット」を基準にした
    // 上乗せ額として扱う（= 直面額 + ポット割合）。目安であり、
    // ソルバーで検証した最適レイズ額ではない。
    return [
      for (final fraction in potFractionPresets)
        _roundToQuarter(facingBb + (potBb + facingBb) * fraction),
    ];
  }

  /// 0.33 のようなポット割合を掛けた浮動小数点の誤差（例:
  /// `0.8250000000000001`）が画面にそのまま出ないよう、0.25BB 刻みに
  /// 丸める。実戦のベットサイズとしても、この粒度で十分細かい。
  static double _roundToQuarter(double value) => (value * 4).round() / 4;
}
