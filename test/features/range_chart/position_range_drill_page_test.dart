import 'package:ai_poker_coach/features/range_chart/presentation/position_range_drill_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PositionRangeDrillPage())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('初期表示はBTNのオープンで、169マスの表が出る', (tester) async {
    await pumpPage(tester);

    expect(find.text('ポジション別レンジ暗記'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('オープン'), findsOneWidget);
  });

  testWidgets('UTGを選ぶとvsオープンの選択肢が消える', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('UTG'));
    await tester.pumpAndSettle();

    expect(find.text('vsオープン'), findsNothing);
  });

  testWidgets('BBを選ぶとオープンが無く、vsオープンだけになる', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('BB'));
    await tester.pumpAndSettle();

    expect(find.text('オープン'), findsNothing);
    expect(find.text('vsオープン'), findsOneWidget);
  });

  testWidgets('ハンドを塗って回答すると正解数が出る', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('AA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回答する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('正解 '), findsOneWidget);
  });
}
