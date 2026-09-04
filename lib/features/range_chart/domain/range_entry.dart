import '../../../shared/models/starting_hand.dart';
import 'range_action.dart';
import 'range_spot.dart';

/// レンジ表の 1 ハンド分のデータ。Supabase の `range_actions` に対応する。
class RangeEntry {
  const RangeEntry({
    required this.hand,
    required this.action,
    required this.frequency,
    this.blend,
  });

  final StartingHand hand;
  final RangeAction action;

  /// そのアクションを取る「目安の頻度」(0.0〜1.0)。
  ///
  /// ソルバーの厳密な出力ではなく、学習用の目安として扱う。
  final double frequency;

  /// [action] が [RangeAction.mixed] のときだけ埋まる、2 アクションの内訳。
  ///
  /// 既存の [action] / [frequency] の意味はこのフィールドの有無に関わらず変わらない
  /// （後方互換）。詳しくは [RangeActionBlend] を参照。
  final RangeActionBlend? blend;
}

/// MIX ハンドの内訳（主アクション・その割合・副アクション）。
///
/// ソルバーの厳密な混合戦略ではなく、学習用に整理した目安の割合として扱う
/// （詳しくは `range_guidance.dart` の注記を参照）。
class RangeActionBlend {
  const RangeActionBlend({
    required this.primary,
    required this.primaryShare,
    required this.secondary,
  });

  /// より頻度の高いアクション。
  final RangeAction primary;

  /// [primary] を取る割合（0.0〜1.0）。
  final double primaryShare;

  /// 残りの割合で取るアクション。
  final RangeAction secondary;

  /// [secondary] を取る割合。常に `1 - primaryShare`。
  double get secondaryShare => 1 - primaryShare;
}

/// 1 つのスポットのレンジ表全体。
class RangeChart {
  const RangeChart({required this.spot, required this.entries});

  final RangeSpot spot;

  /// ハンド表記（`AKs` など）をキーにした 169 件のマップ。
  final Map<String, RangeEntry> entries;

  RangeEntry entryFor(StartingHand hand) =>
      entries[hand.code] ??
      RangeEntry(hand: hand, action: RangeAction.fold, frequency: 1);

  /// レンジに含まれるハンドの割合（Fold を除いた 169 分の割合）。
  ///
  /// 組み合わせ数で重み付けする（ペア6通り / スーテッド4通り / オフスート12通り）。
  double get vpipPercent {
    var played = 0.0;
    for (final hand in StartingHand.all) {
      final entry = entryFor(hand);
      if (entry.action == RangeAction.fold) continue;
      played += _combinations(hand) * entry.frequency;
    }
    return played / 1326 * 100;
  }

  static double _combinations(StartingHand hand) => switch (hand.shape) {
    HandShape.pair => 6,
    HandShape.suited => 4,
    HandShape.offsuit => 12,
  };
}
