import 'package:ai_poker_coach/features/hand_review/domain/board_texture.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_flow.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_result.dart';
import 'package:ai_poker_coach/features/hand_review/infrastructure/mock_hand_review_repository.dart';
import 'package:ai_poker_coach/features/range_chart/infrastructure/mock_range_repository.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:flutter_test/flutter_test.dart';

HandAction _hero(PokerActionType action, [double? sizeBb]) =>
    HandAction(actor: HandAction.heroActor, action: action, sizeBb: sizeBb);

HandAction _villain(PokerActionType action, [double? sizeBb]) =>
    HandAction(actor: 'BB', action: action, sizeBb: sizeBb);

void main() {
  const repository = MockHandReviewRepository(MockRangeRepository());

  group('HandReviewInput', () {
    test('仕様書どおりのキーで JSON 化される', () {
      final input = HandReviewInput(
        heroHand: PlayingCard.parseAll(const ['Ah', 'Js']),
        preflop: [_hero(PokerActionType.raise)],
        flop: StreetInput(
          cards: PlayingCard.parseAll(const ['Qs', '7d', '2c']),
          actions: [_hero(PokerActionType.bet)],
        ),
        turn: StreetInput(cards: PlayingCard.parseAll(const ['9h'])),
      );

      final json = input.toJson();
      expect(json['game_type'], 'cash');
      expect(json['table_type'], '6max');
      expect(json['hero_position'], 'BTN');
      expect(json['hero_hand'], ['Ah', 'Js']);
      expect((json['flop']! as Map)['board'], ['Qs', '7d', '2c']);
      expect((json['turn']! as Map)['card'], '9h');
      expect((json['river']! as Map)['card'], isNull);
    });

    test('ハンドと1ストリートぶんの入力が揃うまで送信できない', () {
      // 送信できるかどうかは HandFlow が決める。
      expect(HandFlow(const HandReviewInput()).isReady, isFalse);

      var input = const HandReviewInput().copyWith(
        heroHand: PlayingCard.parseAll(const ['Ah', 'Js']),
      );
      expect(HandFlow(input).isReady, isFalse);

      // 降りればそこでハンドは終わるので、レビューできる。
      input = input.copyWith(preflop: [_hero(PokerActionType.fold)]);
      expect(HandFlow(input).isReady, isTrue);
    });
  });

  group('HandReviewResult', () {
    test('仕様書の出力 JSON を往復できる', () {
      const result = HandReviewResult(
        score: 82,
        summary: 'summary',
        goodPoints: ['good'],
        mainImprovement: 'improve',
        streetAnalysis: {'preflop': 'p', 'flop': 'f', 'turn': '', 'river': ''},
        gtoView: 'gto',
        practicalAdjustment: 'practical',
        alternativeLines: ['alt'],
        nextFocus: 'next',
        relatedQuizTopics: ['preflop'],
      );

      final restored = HandReviewResult.fromJson(result.toJson());
      expect(restored.score, 82);
      expect(restored.goodPoints, ['good']);
      expect(restored.streetAnalysis['preflop'], 'p');
      expect(restored.relatedQuizTopics, ['preflop']);
    });

    test('欠けたキーがあっても既定値で復元できる', () {
      final restored = HandReviewResult.fromJson(const {'score': 50});
      expect(restored.score, 50);
      expect(restored.goodPoints, isEmpty);
      expect(restored.summary, '');
    });
  });

  group('BoardTexture', () {
    test('レインボーで離れたボードはドライ', () {
      final texture = BoardTexture.of(
        PlayingCard.parseAll(const ['Qs', '7d', '2c']),
      )!;
      expect(texture.wetness, BoardWetness.dry);
      expect(texture.isHighCardBoard, isTrue);
    });

    test('ツートーンで繋がったボードはウェット', () {
      final texture = BoardTexture.of(
        PlayingCard.parseAll(const ['9h', '8h', '5c']),
      )!;
      expect(texture.wetness, BoardWetness.wet);
      expect(texture.hasStraightDraw, isTrue);
    });

    test('モノトーンはウェット', () {
      final texture = BoardTexture.of(
        PlayingCard.parseAll(const ['Ks', '9s', '4s']),
      )!;
      expect(texture.isMonotone, isTrue);
      expect(texture.wetness, BoardWetness.wet);
    });

    test('3枚未満は判定できない', () {
      expect(BoardTexture.of(PlayingCard.parseAll(const ['Ks'])), isNull);
    });
  });

  group('MockHandReviewRepository', () {
    test('レンジ外のハンドでのオープンは減点され、改善点に出る', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.utg,
          heroHand: PlayingCard.parseAll(const ['7h', '2d']),
          preflop: [
            _hero(PokerActionType.raise),
            _villain(PokerActionType.fold),
          ],
        ),
      );

      expect(result.mainImprovement, contains('72o'));
      expect(result.relatedQuizTopics, contains('preflop'));
    });

    test('レンジ外のオープンは、レンジ内のオープンより点が低い', () {
      HandReviewInput open(Position position, List<String> hand) =>
          HandReviewInput(
            heroPosition: position,
            heroHand: PlayingCard.parseAll(hand),
            preflop: [
              _hero(PokerActionType.raise, 2.5),
              _villain(PokerActionType.fold),
            ],
          );

      final outOfRange = repository.analyze(open(Position.utg, ['7h', '2d']));
      final inRange = repository.analyze(open(Position.btn, ['Ah', 'Kh']));
      expect(outOfRange.score, lessThan(inRange.score));
    });

    test('レンジ内のオープンは良かった点になる', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.btn,
          heroHand: PlayingCard.parseAll(const ['Ah', 'Kh']),
          preflop: [
            _hero(PokerActionType.raise),
            _villain(PokerActionType.fold),
          ],
        ),
      );

      expect(result.goodPoints.first, contains('AKs'));
    });

    test('リンプは必ず改善点として指摘される', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.co,
          heroHand: PlayingCard.parseAll(const ['Ah', 'Kh']),
          preflop: [_hero(PokerActionType.call)],
        ),
      );

      expect(result.mainImprovement, contains('リンプ'));
    });

    test('ドライボードでの大きいベットはサイズの指摘になる', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.btn,
          heroHand: PlayingCard.parseAll(const ['Ah', 'Kd']),
          preflop: [
            _hero(PokerActionType.raise, 2.5),
            _villain(PokerActionType.call),
          ],
          flop: StreetInput(
            cards: PlayingCard.parseAll(const ['Qs', '7d', '2c']),
            actions: [
              _villain(PokerActionType.check),
              // ポット 5.5BB に対して 4.5BB なので約82%。
              _hero(PokerActionType.bet, 4.5),
            ],
          ),
        ),
      );

      expect(result.relatedQuizTopics, contains('bet_sizing'));
      expect(result.mainImprovement, contains('82%'));
      expect(result.alternativeLines, isNotEmpty);
    });

    test('額を入れていなければサイズの指摘はしない（数字を装わない）', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.btn,
          heroHand: PlayingCard.parseAll(const ['Ah', 'Kd']),
          preflop: [
            _hero(PokerActionType.raise),
            _villain(PokerActionType.call),
          ],
          flop: StreetInput(
            cards: PlayingCard.parseAll(const ['Qs', '7d', '2c']),
            actions: [
              _villain(PokerActionType.check),
              _hero(PokerActionType.bet),
            ],
          ),
        ),
      );

      expect(result.relatedQuizTopics, isNot(contains('bet_sizing')));
    });

    test('相手の傾向ごとに実戦調整が変わる', () {
      HandReviewInput base(VillainProfile profile) => HandReviewInput(
        heroPosition: Position.btn,
        heroHand: PlayingCard.parseAll(const ['Ah', 'Kh']),
        villainProfile: profile,
        preflop: [_hero(PokerActionType.raise)],
      );

      final tight = repository.analyze(base(VillainProfile.tight));
      final loose = repository.analyze(base(VillainProfile.loose));
      expect(tight.practicalAdjustment, isNot(loose.practicalAdjustment));
    });

    test('指摘が無いときのサマリーは「直す」話にならない', () {
      final result = repository.analyze(
        HandReviewInput(
          heroPosition: Position.btn,
          heroHand: PlayingCard.parseAll(const ['As', 'Ks']),
          preflop: [_hero(PokerActionType.raise)],
        ),
      );

      expect(result.mainImprovement, contains('見当たりません'));
      expect(result.summary, isNot(contains('ここを直すと')));
    });

    test('ストリート別分析でヒーローは「あなた」と表示される', () {
      final result = repository.analyze(
        HandReviewInput(
          heroHand: PlayingCard.parseAll(const ['As', 'Ks']),
          preflop: [_hero(PokerActionType.raise)],
        ),
      );

      expect(result.streetAnalysis['preflop'], contains('あなた'));
      expect(result.streetAnalysis['preflop'], isNot(contains('hero')));
    });

    test('出力はスコア範囲と必須項目を満たす', () {
      final result = repository.analyze(
        HandReviewInput(
          heroHand: PlayingCard.parseAll(const ['Ah', 'Js']),
          preflop: [_hero(PokerActionType.raise)],
        ),
      );

      expect(result.score, inInclusiveRange(30, 97));
      expect(result.summary, isNotEmpty);
      expect(result.goodPoints, isNotEmpty);
      expect(result.mainImprovement, isNotEmpty);
      expect(
        result.streetAnalysis.keys,
        containsAll(['preflop', 'flop', 'turn', 'river']),
      );
      expect(result.gtoView, isNotEmpty);
      expect(result.practicalAdjustment, isNotEmpty);
      expect(result.nextFocus, isNotEmpty);
    });

    test('review() は非同期でも同じ結果を返す', () async {
      final input = HandReviewInput(
        heroHand: PlayingCard.parseAll(const ['Ah', 'Js']),
        preflop: [_hero(PokerActionType.raise)],
      );
      final result = await repository.review(input);
      expect(result.score, repository.analyze(input).score);
    });
  });
}
