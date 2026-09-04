import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/presentation/widgets/action_prompt_card.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  ActionPrompt prompt,
  void Function(PokerActionType, double?) onAdd,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActionPromptCard(prompt: prompt, onAdd: onAdd),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ActionPrompt _promptFrom(HandReviewInput input) =>
    (HandFlow(input).step as NeedAction).prompt;

HandReviewInput _base() => HandReviewInput(
  heroPosition: Position.btn,
  villainPosition: Position.bb,
  heroHand: PlayingCard.parseAll(const ['Ah', 'Qs']),
);

void main() {
  testWidgets('誰の番かを選ばせず、ポジションつきで示す', (tester) async {
    await _pump(tester, _promptFrom(_base()), (_, _) {});

    expect(find.textContaining('BTN（あなた）の番です'), findsOneWidget);
    // 相手かどうかを選ぶ切り替えは無い。
    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('賭けに直面しているときは必要な勝率を出す', (tester) async {
    final input = _base().copyWith(
      preflop: const [
        HandAction(
          actor: HandAction.heroActor,
          action: PokerActionType.raise,
          sizeBb: 2.5,
        ),
      ],
    );
    await _pump(tester, _promptFrom(input), (_, _) {});

    // 相手は 1.5BB のコールで、ポットは 4BB。1.5 / 5.5 = 約27%。
    expect(find.textContaining('コールに 1.5BB'), findsOneWidget);
    expect(find.textContaining('必要な勝率は約27%'), findsOneWidget);
  });

  testWidgets('フォールドやチェックは1タップで確定する', (tester) async {
    PokerActionType? chosen;
    double? size;
    await _pump(tester, _promptFrom(_base()), (action, value) {
      chosen = action;
      size = value;
    });

    await tester.tap(find.text('フォールド'));
    await tester.pumpAndSettle();

    expect(chosen, PokerActionType.fold);
    expect(size, isNull);
  });

  testWidgets('レイズを選ぶと額を聞かれ、分からなければ飛ばせる', (tester) async {
    PokerActionType? chosen;
    double? size;
    var called = false;
    await _pump(tester, _promptFrom(_base()), (action, value) {
      chosen = action;
      size = value;
      called = true;
    });

    await tester.tap(find.text('レイズ'));
    await tester.pumpAndSettle();

    // まだ確定していない。
    expect(called, isFalse);
    expect(find.textContaining('いくらまで上げた？'), findsOneWidget);

    await tester.tap(find.text('分からない'));
    await tester.pumpAndSettle();

    expect(chosen, PokerActionType.raise);
    expect(size, isNull);
  });

  testWidgets('プリフロップの最初のレイズは BB 単位の候補を出す', (tester) async {
    PokerActionType? chosen;
    double? size;
    await _pump(tester, _promptFrom(_base()), (action, value) {
      chosen = action;
      size = value;
    });

    await tester.tap(find.text('レイズ'));
    await tester.pumpAndSettle();

    expect(find.text('2.5BB'), findsOneWidget);
    await tester.tap(find.text('2.5BB'));
    await tester.pumpAndSettle();

    expect(chosen, PokerActionType.raise);
    expect(size, 2.5);
  });

  testWidgets('ポストフロップのベットはポット比の候補を出す', (tester) async {
    final input = _base().copyWith(
      preflop: const [
        HandAction(
          actor: HandAction.heroActor,
          action: PokerActionType.raise,
          sizeBb: 2.5,
        ),
        HandAction(actor: 'BB', action: PokerActionType.call),
      ],
      flop: StreetInput(
        cards: PlayingCard.parseAll(const ['Ad', '7c', '2s']),
        actions: const [HandAction(actor: 'BB', action: PokerActionType.check)],
      ),
    );
    double? size;
    await _pump(tester, _promptFrom(input), (_, value) => size = value);

    await tester.tap(find.text('ベット'));
    await tester.pumpAndSettle();

    // ポットは 5.5BB なので、1/3 は約1.8 → 0.5 刻みで 2。
    expect(find.text('ポットの1/3'), findsOneWidget);
    await tester.tap(find.text('ポットの1/3'));
    await tester.pumpAndSettle();

    expect(size, 2);
  });
}
