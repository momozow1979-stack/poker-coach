import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/gto_strategy/application/gto_flop_providers.dart';
import 'package:ai_poker_coach/features/gto_strategy/domain/gto_flop_strategy.dart';
import 'package:ai_poker_coach/features/gto_strategy/presentation/gto_flop_page.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GtoFlopStrategy _fixture() => GtoFlopStrategy(
  matchupId: 'btn_bb',
  matchupLabel: 'BTN open vs BB call (single-raised pot)',
  oopLabel: 'BB (defender)',
  ipLabel: 'BTN (aggressor)',
  spots: [
    GtoFlopSpot(
      id: 'a_high_dry',
      board: PlayingCard.parseAll(const ['As', '7d', '2c']),
      nodes: {
        'oop_first': const GtoActionNode(
          passiveAction: 'x',
          frequencies: {
            'AA': {'x': 0.08, '2': 0.92},
            'KK': {'x': 0.2, '2': 0.8},
            '72o': {'x': 0.95, '2': 0.05},
            'JTs': {'x': 0.5, '2': 0.5},
          },
        ),
        'ip_vs_bet_2': const GtoActionNode(
          passiveAction: 'f',
          frequencies: {
            'AA': {'f': 0.05, 'c': 0.75, '2': 0.2},
          },
        ),
        'oop_vs_raise': const GtoActionNode(
          passiveAction: 'f',
          frequencies: {
            'AA': {'f': 0.1, 'c': 0.9},
          },
        ),
      },
      turns: {
        'blank': GtoStreetNode(
          card: PlayingCard.parse('3s'),
          nodes: const {
            'oop_first': GtoActionNode(
              passiveAction: 'x',
              frequencies: {
                'AA': {'x': 0.3, '2': 0.7},
              },
            ),
          },
        ),
        'over': GtoStreetNode(
          card: PlayingCard.parse('Ks'),
          nodes: const {
            'oop_first': GtoActionNode(
              passiveAction: 'x',
              frequencies: {
                'AA': {'x': 0.4, '2': 0.6},
              },
            ),
          },
        ),
      },
      rivers: {
        'blank': {
          'blank': GtoStreetNode(
            card: PlayingCard.parse('4h'),
            nodes: const {
              'oop_first': GtoActionNode(
                passiveAction: 'x',
                frequencies: {
                  'AA': {'x': 0.45, '2': 0.55},
                },
              ),
            },
          ),
          'scare': GtoStreetNode(
            card: PlayingCard.parse('Kd'),
            nodes: const {
              'oop_first': GtoActionNode(
                passiveAction: 'x',
                frequencies: {
                  'AA': {'x': 0.35, '2': 0.65},
                },
              ),
            },
          ),
        },
      },
    ),
    GtoFlopSpot(
      id: 'paired',
      board: PlayingCard.parseAll(const ['Jd', 'Jc', '6s']),
      nodes: {
        'oop_first': const GtoActionNode(
          passiveAction: 'x',
          frequencies: {
            'AA': {'x': 0.6, '2': 0.4},
            'AKs': {'x': 0.4, '2': 0.6},
          },
        ),
      },
    ),
  ],
);

GtoFlopStrategy _fixtureSecondMatchup() => GtoFlopStrategy(
  matchupId: 'hj_utg_6max',
  matchupLabel: 'UTG open vs HJ call, 6max (single-raised pot)',
  oopLabel: 'HJ (defender)',
  ipLabel: 'UTG (aggressor)',
  spots: [
    GtoFlopSpot(
      id: 'a_high_dry',
      board: PlayingCard.parseAll(const ['As', '7d', '2c']),
      nodes: const {
        'oop_first': GtoActionNode(
          passiveAction: 'x',
          frequencies: {
            'AA': {'x': 0.1, '2': 0.9},
          },
        ),
      },
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  List<GtoFlopStrategy>? catalog,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gtoMatchupCatalogProvider.overrideWith(
          (ref) async => catalog ?? [_fixture()],
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const GtoFlopPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GTOフロップ戦略ヒートマップが描画される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    expect(find.text('GTOフロップ戦略'), findsOneWidget);
    // 13×13 のグリッドなのでハンドコードが並ぶ。
    expect(find.text('AA'), findsWidgets);
    expect(find.text('JTs'), findsWidgets);
  });

  testWidgets('マスをタップするとベット/チェック頻度が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();

    // 凡例の「チェック」「ベット」に加え、明細シートの行にも出る。
    expect(find.text('ベット 1/2'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
  });

  testWidgets('ノードを facing-bet 系に切り替えるとフォールド/コール内訳が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    await tester.tap(find.text('IP vs 1/2ベット'));
    await tester.pumpAndSettle();

    // facing-bet ノードでは凡例が「フォールド/コール＋レイズ」に変わる。
    expect(find.text('フォールド'), findsWidgets);
    expect(find.text('コール＋レイズ'), findsOneWidget);

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();

    // 明細シートは f/c/各ベットサイズをそれぞれ別の行として表示する。
    expect(find.text('5%'), findsOneWidget); // フォールド
    expect(find.text('75%'), findsOneWidget); // コール
    expect(find.text('20%'), findsOneWidget); // レイズ(1/2ポット)
  });

  testWidgets('レイズに直面したノードには代表例のみという開示が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    await tester.tap(find.text('OOP vs レイズ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('代表例のみ'), findsOneWidget);

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();

    // facing-raise ノードは f/c のみ。コール(0.9)がそのまま出る。
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
  });

  testWidgets('ターンタブに切り替えるとターンの頻度とディスクロージャーが出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    await tester.tap(find.text('ターン'));
    await tester.pumpAndSettle();

    // フロップでチェックが続いた場合のみ、という開示が出る。
    expect(find.textContaining('チェックが続いた場合'), findsOneWidget);
    // デフォルトの'blank'バケット（3s）での頻度に切り替わる。
    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('リバーのバケットを切り替えると頻度が変わる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    await tester.tap(find.text('リバー'));
    await tester.pumpAndSettle();
    expect(find.textContaining('フロップ・ターンでチェックが続いた場合'), findsOneWidget);

    await tester.tap(find.text('スケア K♦'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();
    expect(find.text('65%'), findsOneWidget);
  });

  testWidgets('ターン/リバーのデータが無いスポットでも落ちない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    // 2番目(paired)にはturns/riversが無い。board チップは1枚ずつ別の
    // Text になっているので、paired 固有のカード 'J♦' でタップする。
    await tester.tap(find.text('J♦'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ターン'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('マッチアップが複数あると切り替えチップが出て独立して状態が切り替わる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, catalog: [_fixture(), _fixtureSecondMatchup()]);

    // マッチアップが1つだけのときはチップ自体を出さない（既存のテスト群で確認済み）。
    expect(find.text('BTN vs BB'), findsOneWidget);
    expect(find.text('UTG vs HJ'), findsOneWidget);

    await tester.tap(find.text('UTG vs HJ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AA').first);
    await tester.pumpAndSettle();
    expect(find.text('90%'), findsOneWidget);
  });
}
