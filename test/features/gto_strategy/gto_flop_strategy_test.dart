import 'package:ai_poker_coach/features/gto_strategy/domain/gto_flop_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

/// `solver/solve_srp_btn_bb.py` の実際の出力スキーマ（PR #87 でフロップ/ターン/
/// リバー・レイズ対応に拡張されたもの）の最小再現。`flop` の下には
/// `oop_first`（チェック or 4段階ベット）だけでなく、`ip_vs_bet_2`
/// （OOPの1/2ポットベットに対するIPのフォールド/コール/レイズ）のような
/// 他の意思決定ノードも並ぶ（`_STREET_NODES`参照）。
Map<String, dynamic> _rawSpot() => {
  'id': 'a_high_dry',
  'board': ['As', '7d', '2c'],
  'iterations': 12000000,
  'flop': {
    'oop_first': {
      'AA': {'x': 0.1, '1': 0.2, '2': 0.3, '3': 0.25, '4': 0.15, 'combos': 6},
      '72o': {
        'x': 0.9,
        '1': 0.05,
        '2': 0.03,
        '3': 0.01,
        '4': 0.01,
        'combos': 9,
      },
    },
    'ip_vs_bet_2': {
      'AA': {
        'f': 0.05,
        'c': 0.75,
        '1': 0.1,
        '2': 0.05,
        '3': 0.03,
        '4': 0.02,
        'combos': 6,
      },
    },
  },
  'turns': <String, dynamic>{},
  'rivers': <String, dynamic>{},
};

/// ターン・リバーを含む実スキーマの最小再現。`turns.blank.nodes.oop_first` に
/// フロップと同じ形のハンドクラス別頻度が入り、`rivers` はターンのバケット
/// （`'blank'`）→ リバーのバケット（`'blank'`/`'scare'`）の二重構造になる。
Map<String, dynamic> _rawSpotWithStreets() => {
  ..._rawSpot(),
  'turns': {
    'blank': {
      'card': '3s',
      'nodes': {
        'oop_first': {
          'AA': {'x': 0.2, '1': 0.3, '2': 0.2, '3': 0.2, '4': 0.1, 'combos': 6},
        },
      },
    },
  },
  'rivers': {
    'blank': {
      'blank': {
        'card': '4h',
        'nodes': {
          'oop_first': {
            'AA': {
              'x': 0.1,
              '1': 0.3,
              '2': 0.3,
              '3': 0.2,
              '4': 0.1,
              'combos': 6,
            },
          },
        },
      },
      'scare': {
        'card': 'Kd',
        'nodes': {
          'oop_first': {
            'AA': {
              'x': 0.4,
              '1': 0.2,
              '2': 0.2,
              '3': 0.1,
              '4': 0.1,
              'combos': 6,
            },
          },
        },
      },
    },
  },
};

void main() {
  test('GtoFlopSpot.fromJson は oop_first のベットサイズ合計を読む（チェック以外）', () {
    final spot = GtoFlopSpot.fromJson(_rawSpot());

    expect(spot.id, 'a_high_dry');
    expect(spot.board.length, 3);
    final oopFirst = spot.nodes['oop_first']!;
    expect(oopFirst.passiveAction, 'x');
    // チェック以外(1+2+3+4)の合計。
    expect(oopFirst.aggressionFor('AA'), closeTo(0.9, 1e-9));
    expect(oopFirst.aggressionFor('72o'), closeTo(0.1, 1e-9));
    expect(oopFirst.aggressionFor('存在しないコード'), isNull);
  });

  test('GtoFlopSpot.fromJson は facing-bet ノードをフォールド以外の合計として読む', () {
    final spot = GtoFlopSpot.fromJson(_rawSpot());

    final ipVsBet2 = spot.nodes['ip_vs_bet_2']!;
    expect(ipVsBet2.passiveAction, 'f');
    // フォールド以外(c+1+2+3+4)の合計。
    expect(ipVsBet2.aggressionFor('AA'), closeTo(0.95, 1e-9));
    expect(ipVsBet2.actionsFor('AA'), {
      'f': 0.05,
      'c': 0.75,
      '1': 0.1,
      '2': 0.05,
      '3': 0.03,
      '4': 0.02,
    });
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
    expect(GtoFlopStrategy.fromJson({'spots': 'not-a-list'}).spots, isEmpty);
  });

  test('GtoFlopStrategy.fromJson はマッチアップのメタ情報を読む', () {
    final strategy = GtoFlopStrategy.fromJson({
      'matchup_id': 'hj_utg_6max',
      'matchup': 'UTG open vs HJ call, 6max (single-raised pot)',
      'oop_position': 'HJ (defender)',
      'ip_position': 'UTG (aggressor)',
      'spots': [_rawSpot()],
    });

    expect(strategy.matchupId, 'hj_utg_6max');
    expect(
      strategy.matchupLabel,
      'UTG open vs HJ call, 6max (single-raised pot)',
    );
    expect(strategy.oopLabel, 'HJ (defender)');
    expect(strategy.ipLabel, 'UTG (aggressor)');
    expect(strategy.shortLabel, 'UTG vs HJ');
  });

  test('matchup_id が無い古いエクスポートは btn_bb として扱う（後方互換）', () {
    final strategy = GtoFlopStrategy.fromJson({
      'spots': [_rawSpot()],
    });

    expect(strategy.matchupId, 'btn_bb');
    expect(strategy.matchupLabel, '');
  });

  test('GtoFlopSpot.fromJson は turns/rivers の代表カードと頻度を読む', () {
    final spot = GtoFlopSpot.fromJson(_rawSpotWithStreets());

    expect(spot.turns.keys, ['blank']);
    final turnNode = spot.turns['blank']!;
    expect(turnNode.card.code, '3s');
    expect(
      turnNode.nodes['oop_first']!.aggressionFor('AA'),
      closeTo(0.8, 1e-9),
    );

    expect(spot.rivers.keys, ['blank']);
    expect(spot.rivers['blank']!.keys, ['blank', 'scare']);

    final riverBlank = spot.rivers['blank']!['blank']!;
    expect(riverBlank.card.code, '4h');
    expect(
      riverBlank.nodes['oop_first']!.aggressionFor('AA'),
      closeTo(0.9, 1e-9),
    );

    final riverScare = spot.rivers['blank']!['scare']!;
    expect(riverScare.card.code, 'Kd');
    expect(
      riverScare.nodes['oop_first']!.aggressionFor('AA'),
      closeTo(0.6, 1e-9),
    );
  });

  test('turns/rivers が無い場合は空のMapになる', () {
    final spot = GtoFlopSpot.fromJson(_rawSpot());

    expect(spot.turns, isEmpty);
    expect(spot.rivers, isEmpty);
  });

  test('未知のノード名（combosなどの付随フィールド以外）は無視する', () {
    final spot = GtoFlopSpot.fromJson({
      ..._rawSpot(),
      'flop': {
        ...(_rawSpot()['flop'] as Map<String, dynamic>),
        'something_unexpected': {
          'AA': {'x': 1.0, 'combos': 6},
        },
      },
    });

    expect(spot.nodes.keys, containsAll(['oop_first', 'ip_vs_bet_2']));
    expect(spot.nodes.containsKey('something_unexpected'), isFalse);
  });
}
