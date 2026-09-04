import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/core/theme/canvas_text.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:ai_poker_coach/shared/widgets/collapsible_section.dart';
import 'package:ai_poker_coach/shared/widgets/poker_table_view.dart';
import 'package:ai_poker_coach/shared/widgets/radar_chart.dart';
import 'package:ai_poker_coach/shared/widgets/score_ring.dart';
import 'package:ai_poker_coach/shared/widgets/trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  // CustomPainter で文字を描くときにテーマのフォントが失われると、
  // 日本語が豆腐（□）になる。同じ踏み方を繰り返さないための回帰テスト。
  testWidgets('canvasTextStyle はテーマのフォントを引き継ぐ', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            style = canvasTextStyle(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.fontFamily, AppTheme.light().textTheme.bodyMedium?.fontFamily);
    expect(style.fontFamily, isNotNull);
    expect(style.fontFamilyFallback, isNotEmpty);
  });

  testWidgets('テーブル図は全席を描画する', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 320,
        child: PokerTableView(
          tableType: TableType.sixMax,
          heroPosition: Position.btn,
          villainPosition: Position.bb,
          potLabel: 'Pot 5.5BB',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PokerTableView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('9MAXでもテーブル図が描画できる', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 320,
        child: PokerTableView(
          tableType: TableType.nineMax,
          heroPosition: Position.utg1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('テーブル図の席はタップで選べる', (tester) async {
    final tapped = <Position>[];
    await _pump(
      tester,
      SizedBox(
        width: 320,
        child: PokerTableView(
          tableType: TableType.sixMax,
          heroPosition: Position.utg,
          rotateHeroToBottom: false,
          onSeatTap: tapped.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 6MAX なので席は 6 つぶんのタップ領域が並ぶ。
    expect(find.bySemanticsLabel('BTN を選ぶ'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('BTN を選ぶ'));
    expect(tapped, [Position.btn]);
  });

  testWidgets('表示専用のテーブル図にはタップ領域が無い', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 320,
        child: PokerTableView(
          tableType: TableType.sixMax,
          heroPosition: Position.btn,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('BTN を選ぶ'), findsNothing);
  });

  testWidgets('席順はヒーローを手前に回すかどうかで変わる', (tester) async {
    expect(
      PokerTableView.seatOrder(
        TableType.sixMax,
        Position.btn,
        rotateHeroToBottom: true,
      ).first,
      Position.btn,
    );
    expect(
      PokerTableView.seatOrder(
        TableType.sixMax,
        Position.btn,
        rotateHeroToBottom: false,
      ).first,
      Position.utg,
    );
  });

  testWidgets('推移グラフは点が1つ以下なら案内を出す', (tester) async {
    await _pump(
      tester,
      const SizedBox(width: 300, child: TrendChart(points: [])),
    );
    expect(find.textContaining('データが増えると'), findsOneWidget);
  });

  testWidgets('推移グラフは点が揃えば描画される', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 300,
        child: TrendChart(
          points: [
            TrendPoint(label: '8/1', value: 0.5),
            TrendPoint(label: '8/2', value: 0.8),
            TrendPoint(label: '8/3', value: 0.65),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8/1'), findsNothing); // ラベルは canvas に描かれる
    expect(tester.takeException(), isNull);
  });

  testWidgets('スコアリングは最終値までカウントアップする', (tester) async {
    await _pump(tester, const ScoreRing(score: 84));

    expect(find.text('0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('84'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
  });

  testWidgets('レーダーチャートは軸が3本未満なら場所を取らない', (tester) async {
    await _pump(
      tester,
      const RadarChart(
        axes: [
          RadarAxis(label: 'A', value: 0.5, hasEnoughSamples: true),
          RadarAxis(label: 'B', value: 0.5, hasEnoughSamples: true),
        ],
      ),
    );
    expect(tester.getSize(find.byType(RadarChart)), Size.zero);
  });

  testWidgets('レーダーチャートは軸が揃えば指定サイズで描画される', (tester) async {
    await _pump(
      tester,
      const RadarChart(
        size: 200,
        axes: [
          RadarAxis(label: 'プリ', value: 0.9, hasEnoughSamples: true),
          RadarAxis(label: 'ターン', value: 0.4, hasEnoughSamples: true),
          RadarAxis(label: 'リバー', value: 0.6, hasEnoughSamples: false),
          RadarAxis(label: 'GTO', value: 0.75, hasEnoughSamples: true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(RadarChart)), const Size(200, 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('折りたたみは初期状態で本文を隠し、タップで開く', (tester) async {
    await _pump(
      tester,
      const CollapsibleSection(
        icon: Icons.functions_rounded,
        title: 'GTO視点',
        body: 'ここが本文です',
        accent: Colors.blue,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GTO視点'), findsOneWidget);
    final collapsedHeight = tester
        .getSize(find.byType(CollapsibleSection))
        .height;

    await tester.tap(find.text('GTO視点'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(CollapsibleSection)).height,
      greaterThan(collapsedHeight),
      reason: 'タップすると本文のぶん高さが増える',
    );
  });
}
