import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/infrastructure/mock_hand_review_repository.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:flutter_test/flutter_test.dart';

HandAction _h(PokerActionType action, [double? sizeBb]) =>
    HandAction(actor: HandAction.heroActor, action: action, sizeBb: sizeBb);

HandAction _v(PokerActionType action, [double? sizeBb]) =>
    HandAction(actor: 'BB', action: action, sizeBb: sizeBb);

/// BTN の AQo でトップペア。リバーで相手の 5BB ベットに降りている。
/// 相手は KJ なので、実際にはヒーローが勝っていた。
HandReviewInput _handWithRiverFold({List<String> villainHand = const []}) =>
    HandReviewInput(
      heroPosition: Position.btn,
      villainPosition: Position.bb,
      effectiveStackBb: 100,
      heroHand: PlayingCard.parseAll(const ['Ah', 'Qs']),
      villainHand: PlayingCard.parseAll(villainHand),
      preflop: [_h(PokerActionType.raise, 2.5), _v(PokerActionType.call)],
      flop: StreetInput(
        cards: PlayingCard.parseAll(const ['Ad', '7c', '2s']),
        actions: [
          _v(PokerActionType.check),
          _h(PokerActionType.bet, 2),
          _v(PokerActionType.call),
        ],
      ),
      turn: StreetInput(
        cards: PlayingCard.parseAll(const ['Kc']),
        actions: [
          _v(PokerActionType.check),
          _h(PokerActionType.bet, 3),
          _v(PokerActionType.call),
        ],
      ),
      river: StreetInput(
        cards: PlayingCard.parseAll(const ['9h']),
        actions: [_v(PokerActionType.bet, 5), _h(PokerActionType.fold)],
      ),
    );

void main() {
  const repository = MockHandReviewRepository(MockRangeRepository());

  group('レビューの中身', () {
    test('ストリートごとに、持っている役を言葉で示す', () {
      final result = repository.analyze(_handWithRiverFold());
      expect(result.streetAnalysis['flop'], contains('A のトップペア'));
      // キッカーは自分の2枚目。ボードの K を持ち出さない。
      expect(result.streetAnalysis['turn'], contains('キッカー Q'));
      expect(result.streetAnalysis['turn'], isNot(contains('キッカー K')));
    });

    test('アクションを日本語で並べる', () {
      final result = repository.analyze(_handWithRiverFold());
      expect(result.streetAnalysis['flop'], contains('BB チェック'));
      expect(result.streetAnalysis['flop'], contains('あなた ベット 2BB'));
      expect(result.streetAnalysis['flop'], isNot(contains('Bet')));
    });

    test('直面したコールの必要勝率を、割り算つきで示す', () {
      final result = repository.analyze(_handWithRiverFold());
      // 5 ÷ (20.5 + 5) = 約20%
      expect(result.streetAnalysis['river'], contains('約20%'));
      expect(result.streetAnalysis['river'], contains('5 ÷ 25.5'));
    });

    test('最終ポットをサマリーに出す', () {
      final result = repository.analyze(_handWithRiverFold());
      expect(result.summary, contains('20.5BB'));
    });

    test('相手のハンドが分かれば、その時点の正確な勝率を出す', () {
      final result = repository.analyze(
        _handWithRiverFold(villainHand: const ['Kd', 'Jc']),
      );
      expect(result.streetAnalysis['flop'], contains('この時点での勝率'));
      // 後から見た数字であることを断る。
      expect(result.streetAnalysis['river'], contains('相手の手札が分かっているから'));
    });

    test('相手のハンドが分からなければ勝率を出さない（数字を装わない）', () {
      final result = repository.analyze(_handWithRiverFold());
      for (final text in result.streetAnalysis.values) {
        expect(text, isNot(contains('この時点での勝率')));
      }
    });

    test('値段に合わないフォールドを、相手のハンドから検証して指摘する', () {
      final result = repository.analyze(
        _handWithRiverFold(villainHand: const ['Kd', 'Jc']),
      );
      expect(result.mainImprovement, contains('必要だった勝率は約20%'));
      expect(result.mainImprovement, contains('100%'));
      expect(result.relatedQuizTopics, contains('pot_odds'));
      expect(result.nextFocus, contains('必要な勝率'));
    });

    test('相手のハンドが分からなくても、安すぎるフォールドは指摘する', () {
      final result = repository.analyze(_handWithRiverFold());
      expect(result.mainImprovement, contains('約20%'));
      expect(result.relatedQuizTopics, contains('pot_odds'));
    });

    test('GTO の頻度や EV の数値を書かない', () {
      final result = repository.analyze(
        _handWithRiverFold(villainHand: const ['Kd', 'Jc']),
      );
      final frequency = RegExp(
        r'(GTO|ソルバー|solver)[^。]{0,40}?[0-9]+(\.[0-9]+)?\s*%',
      );
      final ev = RegExp(r'EV\s*[はが＝=:：]?\s*[+\-−]?[0-9]');
      final texts = [
        result.summary,
        result.mainImprovement,
        result.gtoView,
        result.practicalAdjustment,
        result.nextFocus,
        ...result.goodPoints,
        ...result.alternativeLines,
        ...result.streetAnalysis.values,
      ];
      for (final text in texts) {
        expect(frequency.hasMatch(text), isFalse, reason: text);
        expect(ev.hasMatch(text), isFalse, reason: text);
      }
    });
  });
}
