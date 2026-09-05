import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_action.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_entry.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_guidance.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_spot.dart';
import 'package:ai_poker_coach/features/range_chart/presentation/widgets/hand_detail_sheet.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:ai_poker_coach/shared/widgets/action_frequency_bar.dart';

void main() {
  final spot = RangeSpot(
    id: 'test_spot',
    tableType: TableType.sixMax,
    situation: RangeSituation.openRaise,
    heroPosition: Position.btn,
    stackBb: 100,
    title: 'テスト用スポット',
    headline: 'テスト用の見出し',
  );

  RangeHandGuidance guidanceFor(RangeEntry entry) =>
      RangeGuidanceBuilder.build(spot: spot, entry: entry);

  Future<void> pumpSheet(WidgetTester tester, RangeHandGuidance guidance) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandDetailSheet(guidance: guidance, spotTitle: spot.title),
        ),
      ),
    );
  }

  group('HandDetailSheet', () {
    testWidgets('ミックスハンドは ActionFrequencyBar で内訳を表示する', (tester) async {
      final hand = StartingHand.parse('AJs');
      final entry = RangeEntry(
        hand: hand,
        action: RangeAction.mixed,
        frequency: 0.5,
        blend: const RangeActionBlend(
          primary: RangeAction.threeBet,
          primaryShare: 0.5,
          secondary: RangeAction.call,
        ),
      );

      await pumpSheet(tester, guidanceFor(entry));

      // 内訳の視覚的な帯グラフが出て、
      expect(find.byType(ActionFrequencyBar), findsOneWidget);
      // 色だけに頼らず、アクション名+パーセントのテキストも添えられている。
      expect(find.textContaining('3Bet'), findsWidgets);
      expect(find.textContaining('50%'), findsWidgets);
      expect(find.textContaining('Call'), findsWidgets);
      // frequencyLabel の生テキスト（ミックス表記）は帯と重複するため出さない。
      expect(find.textContaining('ミックス'), findsNothing);
      // ハンドの説明文自体は残る。
      expect(find.text(hand.description), findsOneWidget);
    });

    testWidgets('通常（非ミックス）ハンドは従来どおりテキスト表示のまま', (tester) async {
      final hand = StartingHand.parse('AKs');
      final entry = RangeEntry(
        hand: hand,
        action: RangeAction.raise,
        frequency: 1,
      );

      await pumpSheet(tester, guidanceFor(entry));

      expect(find.byType(ActionFrequencyBar), findsNothing);
      expect(
        find.text('${hand.description} ・ ${guidanceFor(entry).frequencyLabel}'),
        findsOneWidget,
      );
    });
  });
}
