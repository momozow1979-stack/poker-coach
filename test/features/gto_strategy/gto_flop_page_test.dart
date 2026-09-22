import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/gto_strategy/application/gto_flop_providers.dart';
import 'package:ai_poker_coach/features/gto_strategy/domain/gto_flop_strategy.dart';
import 'package:ai_poker_coach/features/gto_strategy/presentation/gto_flop_page.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GtoFlopStrategy _fixture() => GtoFlopStrategy(
  spots: [
    GtoFlopSpot(
      id: 'a_high_dry',
      board: PlayingCard.parseAll(const ['As', '7d', '2c']),
      betByCode: const {'AA': 0.92, 'KK': 0.8, '72o': 0.05, 'JTs': 0.5},
    ),
    GtoFlopSpot(
      id: 'paired',
      board: PlayingCard.parseAll(const ['Jd', 'Jc', '6s']),
      betByCode: const {'AA': 0.4, 'AKs': 0.6},
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gtoFlopStrategyProvider.overrideWith((ref) async => _fixture()),
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

    // 「ベット」「チェック」は凡例にもあるので複数。頻度%はシート固有。
    expect(find.text('ベット'), findsWidgets);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
  });
}
