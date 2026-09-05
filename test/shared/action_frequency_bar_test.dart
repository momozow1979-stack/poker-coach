import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/widgets/action_frequency_bar.dart';
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
  group('ActionFrequencyBar', () {
    testWidgets('各区間のラベルとパーセントを表示する', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 300,
          child: ActionFrequencyBar(
            label: '推奨アクション',
            segments: [
              ActionFrequencySegment(
                actionType: PokerActionType.raise,
                share: 0.6,
              ),
              ActionFrequencySegment(
                actionType: PokerActionType.fold,
                share: 0.4,
              ),
            ],
          ),
        ),
      );

      expect(find.text('推奨アクション'), findsOneWidget);
      expect(find.text('Raise 60%'), findsOneWidget);
      expect(find.text('Fold 40%'), findsOneWidget);
      // 色だけに頼らない: アクションごとに異なるアイコンも出ている。
      expect(find.byIcon(PokerActionType.raise.icon), findsOneWidget);
      expect(find.byIcon(PokerActionType.fold.icon), findsOneWidget);
    });

    testWidgets('正規化されていない重みでも正しい割合に直す', (tester) async {
      // 60/40 のような比率ではなく、生の重み（3 対 1）で渡しても
      // 合計に対する割合として表示できることを確認する。
      await _pump(
        tester,
        const SizedBox(
          width: 300,
          child: ActionFrequencyBar(
            segments: [
              ActionFrequencySegment(
                actionType: PokerActionType.call,
                share: 3,
              ),
              ActionFrequencySegment(
                actionType: PokerActionType.raise,
                share: 1,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Call 75%'), findsOneWidget);
      expect(find.text('Raise 25%'), findsOneWidget);
    });

    testWidgets('3区間以上でもパーセントの合計がおおよそ100%になる', (tester) async {
      const shares = [0.5, 0.3, 0.2];
      await _pump(
        tester,
        const SizedBox(
          width: 300,
          child: ActionFrequencyBar(
            segments: [
              ActionFrequencySegment(
                actionType: PokerActionType.raise,
                share: 0.5,
              ),
              ActionFrequencySegment(
                actionType: PokerActionType.call,
                share: 0.3,
              ),
              ActionFrequencySegment(
                actionType: PokerActionType.fold,
                share: 0.2,
              ),
            ],
          ),
        ),
      );

      // 端数の丸めを許容しつつ、表示されたパーセントの合計を検証する。
      final total = shares
          .map((s) => (s * 100).round())
          .reduce((a, b) => a + b);
      expect(total, closeTo(100, 2));
      expect(find.text('Raise 50%'), findsOneWidget);
      expect(find.text('Call 30%'), findsOneWidget);
      expect(find.text('Fold 20%'), findsOneWidget);
    });

    testWidgets('区間が空なら何も描画しない', (tester) async {
      await _pump(
        tester,
        const SizedBox(width: 300, child: ActionFrequencyBar(segments: [])),
      );

      expect(find.byType(ActionFrequencyBar), findsOneWidget);
      // 親の SizedBox が幅 300 を強制するため、幅は 300 のまま伝播するが、
      // 高さは 0（＝何も描画していない）になる。
      expect(tester.getSize(find.byType(ActionFrequencyBar)).height, 0);
    });

    testWidgets('割合が0の区間は表示しない', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 300,
          child: ActionFrequencyBar(
            segments: [
              ActionFrequencySegment(
                actionType: PokerActionType.raise,
                share: 1,
              ),
              ActionFrequencySegment(
                actionType: PokerActionType.fold,
                share: 0,
              ),
            ],
          ),
        ),
      );

      expect(find.textContaining('Fold'), findsNothing);
      expect(find.text('Raise 100%'), findsOneWidget);
    });
  });
}
