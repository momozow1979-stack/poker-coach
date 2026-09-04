import 'package:ai_poker_coach/features/range_chart/domain/range_action.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_guidance.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_spot.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/range_definitions.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = MockRangeRepository();

  test('すべてのレンジ表が169ハンドを持つ', () {
    for (final tableType in TableType.values) {
      for (final position in Position.orderFor(tableType)) {
        final chart = repository.chartFor(tableType, position);
        expect(
          chart,
          isNotNull,
          reason: '${tableType.label} ${position.label}',
        );
        expect(chart!.entries, hasLength(169));
      }
    }
  });

  test('AA はどのポジションでも降りない', () {
    for (final tableType in TableType.values) {
      for (final position in Position.orderFor(tableType)) {
        final chart = repository.chartFor(tableType, position)!;
        expect(
          chart.entryFor(StartingHand.parse('AA')).action,
          isNot(RangeAction.fold),
          reason: '${tableType.label} ${position.label}',
        );
      }
    }
  });

  test('72o は UTG のオープンレンジに入らない', () {
    final chart = repository.chartFor(TableType.sixMax, Position.utg)!;
    expect(chart.entryFor(StartingHand.parse('72o')).action, RangeAction.fold);
  });

  test('レンジはポジションが後ろになるほど広がる', () {
    final utg = repository.chartFor(TableType.sixMax, Position.utg)!;
    final co = repository.chartFor(TableType.sixMax, Position.co)!;
    final btn = repository.chartFor(TableType.sixMax, Position.btn)!;

    expect(utg.vpipPercent, lessThan(co.vpipPercent));
    expect(co.vpipPercent, lessThan(btn.vpipPercent));
    expect(btn.vpipPercent, greaterThan(35));
    expect(utg.vpipPercent, lessThan(25));
  });

  test('9MAX の UTG は 6MAX の UTG より狭い', () {
    final sixMax = repository.chartFor(TableType.sixMax, Position.utg)!;
    final nineMax = repository.chartFor(TableType.nineMax, Position.utg)!;
    expect(nineMax.vpipPercent, lessThan(sixMax.vpipPercent));
  });

  test('BB はディフェンス表になり 3Bet と Call を含む', () {
    final chart = repository.chartFor(TableType.sixMax, Position.bb)!;
    final actions = chart.entries.values.map((entry) => entry.action).toSet();
    expect(actions, contains(RangeAction.threeBet));
    expect(actions, contains(RangeAction.call));
  });

  test('スポット ID から取得できる', () {
    final chart = repository.chartById('6max_btn_open');
    expect(chart, isNotNull);
    expect(chart!.spot.heroPosition, Position.btn);
    expect(repository.chartById('unknown_spot'), isNull);
  });

  test('解説はハンドごとに4つの観点を返す', () {
    final chart = repository.chartFor(TableType.sixMax, Position.btn)!;
    final guidance = RangeGuidanceBuilder.build(
      spot: chart.spot,
      entry: chart.entryFor(StartingHand.parse('AKs')),
    );
    expect(guidance.reason, isNotEmpty);
    expect(guidance.beginnerNote, isNotEmpty);
    expect(guidance.gtoNote, isNotEmpty);
    expect(guidance.practicalNote, isNotEmpty);
    expect(guidance.frequencyLabel, contains('Raise'));
  });

  group('vsOpen シナリオ', () {
    const newSixMaxDefensePositions = [
      Position.hj,
      Position.co,
      Position.btn,
      Position.sb,
    ];
    const newNineMaxDefensePositions = [
      Position.utg1,
      Position.mp,
      Position.lj,
      Position.hj,
      Position.co,
      Position.btn,
      Position.sb,
    ];

    test('6MAX: 新設ポジションはすべて situation: vsOpen で取得できる', () {
      for (final position in newSixMaxDefensePositions) {
        final chart = repository.chartFor(
          TableType.sixMax,
          position,
          situation: RangeSituation.vsOpen,
        );
        expect(chart, isNotNull, reason: position.label);
        expect(chart!.entries, hasLength(169));
        expect(chart.spot.situation, RangeSituation.vsOpen);
        final actions = chart.entries.values
            .map((entry) => entry.action)
            .toSet();
        expect(actions, contains(RangeAction.threeBet));
        expect(actions, contains(RangeAction.call));
      }
    });

    test('9MAX: 新設ポジションはすべて situation: vsOpen で取得できる', () {
      for (final position in newNineMaxDefensePositions) {
        final chart = repository.chartFor(
          TableType.nineMax,
          position,
          situation: RangeSituation.vsOpen,
        );
        expect(chart, isNotNull, reason: position.label);
        expect(chart!.entries, hasLength(169));
        expect(chart.spot.situation, RangeSituation.vsOpen);
        final actions = chart.entries.values
            .map((entry) => entry.action)
            .toSet();
        expect(actions, contains(RangeAction.threeBet));
        expect(actions, contains(RangeAction.call));
      }
    });

    test('AA はどの vsOpen シナリオでも 3Bet される', () {
      for (final position in newSixMaxDefensePositions) {
        final chart = repository.chartFor(
          TableType.sixMax,
          position,
          situation: RangeSituation.vsOpen,
        )!;
        expect(
          chart.entryFor(StartingHand.parse('AA')).action,
          RangeAction.threeBet,
          reason: position.label,
        );
      }
    });

    test('situation を省略すると従来どおりオープンレイズ表が返る（後方互換）', () {
      final withoutSituation = repository.chartFor(
        TableType.sixMax,
        Position.hj,
      );
      expect(withoutSituation, isNotNull);
      expect(withoutSituation!.spot.situation, RangeSituation.openRaise);
    });

    test('UTG は vsOpen シナリオを持たない（直前のポジションが無いため）', () {
      final chart = repository.chartFor(
        TableType.sixMax,
        Position.utg,
        situation: RangeSituation.vsOpen,
      );
      expect(chart, isNull);
    });

    test('スポット ID からも正しいシチュエーションが取れる（chartFor と食い違わない）', () {
      final defenseChart = repository.chartById('6max_hj_defense');
      expect(defenseChart, isNotNull);
      expect(defenseChart!.spot.situation, RangeSituation.vsOpen);
      expect(defenseChart.spot.heroPosition, Position.hj);

      final openChart = repository.chartById('6max_hj_open');
      expect(openChart, isNotNull);
      expect(openChart!.spot.situation, RangeSituation.openRaise);
    });
  });

  group('situationsFor', () {
    test('オープン・vsOpen 両方あるポジションは2件返る', () {
      expect(
        RangeDefinitions.situationsFor(TableType.sixMax, Position.hj),
        unorderedEquals([RangeSituation.openRaise, RangeSituation.vsOpen]),
      );
      expect(
        RangeDefinitions.situationsFor(TableType.nineMax, Position.co),
        unorderedEquals([RangeSituation.openRaise, RangeSituation.vsOpen]),
      );
    });

    test('UTG はオープンしか無いので1件だけ返る', () {
      expect(RangeDefinitions.situationsFor(TableType.sixMax, Position.utg), [
        RangeSituation.openRaise,
      ]);
      expect(RangeDefinitions.situationsFor(TableType.nineMax, Position.utg), [
        RangeSituation.openRaise,
      ]);
    });

    test('BB は vsOpen しか無いので1件だけ返る', () {
      expect(RangeDefinitions.situationsFor(TableType.sixMax, Position.bb), [
        RangeSituation.vsOpen,
      ]);
    });
  });

  group('MIX ハンドのブレンド', () {
    test('すべての MIX ハンドで primaryShare + secondaryShare が1.0になる', () {
      for (final tableType in TableType.values) {
        for (final position in Position.orderFor(tableType)) {
          for (final situation in RangeDefinitions.situationsFor(
            tableType,
            position,
          )) {
            final chart = repository.chartFor(
              tableType,
              position,
              situation: situation,
            )!;
            for (final entry in chart.entries.values) {
              if (entry.action != RangeAction.mixed) continue;
              final blend = entry.blend;
              expect(
                blend,
                isNotNull,
                reason:
                    '${tableType.label} ${position.label} ${entry.hand.code}',
              );
              expect(
                blend!.primaryShare + blend.secondaryShare,
                closeTo(1.0, 1e-9),
                reason:
                    '${tableType.label} ${position.label} ${entry.hand.code}',
              );
            }
          }
        }
      }
    });

    test('非MIXハンドは blend を持たない', () {
      final chart = repository.chartFor(TableType.sixMax, Position.btn)!;
      final raised = chart.entryFor(StartingHand.parse('AA'));
      expect(raised.action, isNot(RangeAction.mixed));
      expect(raised.blend, isNull);
    });

    test('vsOpen の MIX ハンドは3Bet/Callの内訳を持つ', () {
      final chart = repository.chartFor(
        TableType.sixMax,
        Position.hj,
        situation: RangeSituation.vsOpen,
      )!;
      final mixedHand = chart.entryFor(StartingHand.parse('JJ'));
      expect(mixedHand.action, RangeAction.mixed);
      expect(mixedHand.blend, isNotNull);
      expect(mixedHand.blend!.primary, RangeAction.threeBet);
      expect(mixedHand.blend!.secondary, RangeAction.call);

      final guidance = RangeGuidanceBuilder.build(
        spot: chart.spot,
        entry: mixedHand,
      );
      expect(guidance.frequencyLabel, contains('3Bet'));
      expect(guidance.frequencyLabel, contains('Call'));
      expect(guidance.frequencyLabel, contains('50%'));
    });
  });
}
