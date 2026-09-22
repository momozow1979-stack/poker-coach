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

  /// レベル番号（1〜6）。見習い=Lv.1、名人=Lv.6。表示の「Lv.N」に使う。
  int get level => index + 1;

  /// 座学のユニーク正解数と、レンジ表暗記のクリア状況から昇格を決める。
  ///
  /// 「正答率だけ」ではなく「どれだけ身につけたか（正解した問題数）」を主軸にし、
  /// 後半はレンジ暗記のクリアを条件に足す。数値は学習用の目安。
  static GrowthRank forProgress({
    required int uniqueSolved,
    required bool openDrillCleared,
    required bool vsOpenDrillCleared,
  }) {
    if (uniqueSolved >= 700 && openDrillCleared && vsOpenDrillCleared) {
      return GrowthRank.master;
    }
    if (uniqueSolved >= 450 && vsOpenDrillCleared) return GrowthRank.expert;
    if (uniqueSolved >= 250 && openDrillCleared) return GrowthRank.skilled;
    if (uniqueSolved >= 100) return GrowthRank.journeyman;
    if (uniqueSolved >= 30) return GrowthRank.training;
    return GrowthRank.apprentice;
  }
}
