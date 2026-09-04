import 'package:ai_poker_coach/features/range_chart/domain/range_action.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_entry.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_spot.dart';
import 'package:ai_poker_coach/features/range_chart/presentation/widgets/range_matrix.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const spot = RangeSpot(
    id: 'test_spot',
    tableType: TableType.sixMax,
    situation: RangeSituation.vsOpen,
    heroPosition: Position.hj,
    villainPosition: Position.utg,
    stackBb: 100,
    title: 'テスト用スポット',
    headline: 'テスト',
  );

  RangeChart chartWith(RangeEntry mixedEntryForJJ) {
    final entries = <String, RangeEntry>{
      for (final hand in StartingHand.all)
        hand.code: RangeEntry(
          hand: hand,
          action: RangeAction.fold,
          frequency: 1,
        ),
    };
    entries['JJ'] = mixedEntryForJJ;
    return RangeChart(spot: spot, entries: entries);
  }

  testWidgets('ブレンド付きの MIX セルは主・副 2 色と両方の記号を表示する', (tester) async {
    final blend = const RangeActionBlend(
      primary: RangeAction.threeBet,
      primaryShare: 0.5,
      secondary: RangeAction.call,
    );
    final chart = chartWith(
      RangeEntry(
        hand: StartingHand.parse('JJ'),
        action: RangeAction.mixed,
        frequency: 0.5,
        blend: blend,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: RangeMatrix(chart: chart, onHandTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 色だけに頼らない: 両方のアクションの記号が併記されていること。
    expect(
      find.text('${RangeAction.threeBet.symbol}/${RangeAction.call.symbol}'),
      findsOneWidget,
    );

    // セマンティクスに両方のアクション名・割合が含まれていること
    // （フラットな "状況次第" プレースホルダーではない）。
    final semanticsWidget = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere(
          (widget) => widget.properties.label?.contains('JJ') ?? false,
        );
    final label = semanticsWidget.properties.label!;
    expect(label, contains(RangeAction.threeBet.label));
    expect(label, contains(RangeAction.call.label));
    expect(label, contains('50%'));

    // 塗り分け: 主・副 2 色のコンテナが両方描画されていること
    // （旧来の単色 rangeMixed 塗りつぶし1つだけ、ではない）。
    final coloredBoxes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .toList();
    expect(coloredBoxes.length, greaterThanOrEqualTo(2));
    final colors = coloredBoxes.map((box) => box.color).toSet();
    expect(
      colors,
      contains(RangeAction.threeBet.color.withValues(alpha: 0.85)),
    );
    expect(colors, contains(RangeAction.call.color.withValues(alpha: 0.85)));
    expect(colors.length, greaterThanOrEqualTo(2));
  });

  testWidgets('blend が無い通常の MIX セルは従来どおり単色・単一記号のまま', (tester) async {
    final chart = chartWith(
      RangeEntry(
        hand: StartingHand.parse('JJ'),
        action: RangeAction.mixed,
        frequency: 0.5,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: RangeMatrix(chart: chart, onHandTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(RangeAction.mixed.symbol), findsOneWidget);
    // 従来の単色塗りは Container の decoration であって、
    // ブレンド用の _MixedFill（ColoredBox 2枚）は使われない。
    expect(
      find.text('${RangeAction.threeBet.symbol}/${RangeAction.call.symbol}'),
      findsNothing,
    );
  });
}
