/// 「見習い」から「名人」までの上達ランク。
///
/// 動物アイコンは体の大きさで成長を表す（ねずみ→ぞう）。
/// 他ユーザーとの相対順位（「上位◯%」）はサーバー側の集計が無いと出せない
/// ため、自分の正答率だけで決まる絶対評価にしている。
enum GrowthRank {
  apprentice('見習い', '🐭'),
  training('修行中', '🐱'),
  journeyman('一人前', '🐶'),
  skilled('熟練', '🐯'),
  expert('達人', '🐻'),
  master('名人', '🐘');

  const GrowthRank(this.label, this.emoji);

  final String label;
  final String emoji;

  /// 全体正答率と回答数からランクを決める。
  ///
  /// 回答数が少ないうちは正答率がぶれるので、一定数に達するまでは
  /// 見習いのまま据え置く。
  static GrowthRank forStats({
    required double accuracy,
    required int totalAnswered,
  }) {
    if (totalAnswered < 30) return GrowthRank.apprentice;
    if (accuracy < 0.55) return GrowthRank.apprentice;
    if (accuracy < 0.65) return GrowthRank.training;
    if (accuracy < 0.75) return GrowthRank.journeyman;
    if (accuracy < 0.85) return GrowthRank.skilled;
    if (accuracy < 0.92) return GrowthRank.expert;
    return GrowthRank.master;
  }
}
