import 'package:ai_poker_coach/features/gto_strategy/domain/gto_flop_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

/// `solver/solve_srp_btn_bb.py` の実際の出力スキーマ（PR #87 でフロップ/ターン/
/// リバー・レイズ対応に拡張されたもの）の最小再現。`flop.oop_first` に
/// ハンドクラスごとのチェック(`x`)・4段階ベット(`1`〜`4`)の頻度が入る。
Map<String, dynamic> _rawSpot() => {
  'id': 'a_high_dry',
  'board': ['As', '7d', '2c'],
  'iterations': 12000000,
  'flop': {
    'oop_first': {
      'AA': {'x': 0.1, '1': 0.2, '2': 0.3, '3': 0.25, '4': 0.15, 'combos': 6},
      '72o': {'x': 0.9, '1': 0.05, '2': 0.03, '3': 0.01, '4': 0.01, 'combos': 9},
    },
  },
  'turns': <String, dynamic>{},
  'rivers': <String, dynamic>{},
};

void main() {
  test('GtoFlopSpot.fromJson は flop.oop_first のベットサイズ合計を読む', () {
    final spot = GtoFlopSpot.fromJson(_rawSpot());

    expect(spot.id, 'a_high_dry');
    expect(spot.board.length, 3);
    // チェック以外(1+2+3+4)の合計。
    expect(spot.betFor('AA'), closeTo(0.9, 1e-9));
    expect(spot.betFor('72o'), closeTo(0.1, 1e-9));
    expect(spot.betFor('存在しないコード'), isNull);
  });

  test('GtoFlopStrategy.fromJson は spots 配列をそのまま変換する', () {
    final strategy = GtoFlopStrategy.fromJson({
      'spots': [_rawSpot()],
    });

    expect(strategy.spots, hasLength(1));
    expect(strategy.spots.single.id, 'a_high_dry');
  });

  test('spots が無い/型が違う場合は空のリストになる', () {
    expect(GtoFlopStrategy.fromJson(const {}).spots, isEmpty);
    expect(
      GtoFlopStrategy.fromJson({'spots': 'not-a-list'}).spots,
      isEmpty,
    );
  });
}
