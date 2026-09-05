import 'package:ai_poker_coach/core/theme/app_theme.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/banks/preflop_quizzes.dart';
import 'package:ai_poker_coach/features/quiz/infrastructure/quiz_bank.dart';
import 'package:ai_poker_coach/features/quiz/presentation/widgets/quiz_explanation_view.dart';
import 'package:ai_poker_coach/features/range_chart/application/range_providers.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_action.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_entry.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_repository.dart';
import 'package:ai_poker_coach/features/range_chart/domain/range_spot.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';
import 'package:ai_poker_coach/shared/models/position.dart';
import 'package:ai_poker_coach/shared/models/starting_hand.dart';
import 'package:ai_poker_coach/shared/models/street.dart';
import 'package:ai_poker_coach/shared/models/table_type.dart';
import 'package:ai_poker_coach/shared/widgets/action_frequency_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用に固定のレンジ表（または null）だけを返すリポジトリ。
class _FakeRangeRepository implements RangeRepository {
  _FakeRangeRepository(this._chart);

  final RangeChart? _chart;

  @override
  RangeChart? chartById(String spotId) => _chart;

  @override
  RangeChart? chartFor(
    TableType tableType,
    Position position, {
    RangeSituation? situation,
  }) => null;

  @override
  List<RangeSpot> spotsFor(TableType tableType) => const [];
}

const _spot = RangeSpot(
  id: 'test_spot',
  tableType: TableType.sixMax,
  situation: RangeSituation.openRaise,
  heroPosition: Position.utg,
  stackBb: 100,
  title: 'テスト用スポット',
  headline: 'テスト',
);

RangeChart _chartWith(String handCode, RangeEntry entry) {
  return RangeChart(spot: _spot, entries: {handCode: entry});
}

/// 実データの解決に必要な要素だけを差し替えられるテスト用クイズ。
Quiz _quizWith({
  String? relatedRangeSpotId,
  List<String>? heroCards,
  PokerActionType? correctActionType,
}) {
  return Quiz(
    id: 'test1',
    category: QuizCategory.preflop,
    difficulty: QuizDifficulty.beginner,
    situation: heroCards == null
        ? null
        : QuizSituation(
            tableType: TableType.sixMax,
            street: Street.preflop,
            heroPosition: Position.utg,
            heroCards: PlayingCard.parseAll(heroCards),
            effectiveStackBb: 100,
            potBb: 1.5,
          ),
    question: 'テスト問題',
    choices: [
      QuizChoice(
        id: 'test1-c0',
        label: 'テスト選択肢',
        actionType: correctActionType,
      ),
    ],
    correctChoiceId: 'test1-c0',
    explanation: QuizExplanation(
      shortReason: 'テストの理由',
      gtoView: 'テストのGTO視点',
      practicalView: 'テストの実戦視点',
      commonMistake: 'テストのミス',
      relatedRangeSpotId: relatedRangeSpotId,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Quiz quiz, {
  RangeRepository? repositoryOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repositoryOverride != null)
          rangeRepositoryProvider.overrideWithValue(repositoryOverride),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuizExplanationView(quiz: quiz, isCorrect: true),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QuizExplanationView のレンジ頻度バー', () {
    testWidgets('実在するレンジ表・単一アクションなら頻度バーを表示する', (tester) async {
      final chart = _chartWith(
        'AA',
        RangeEntry(
          hand: StartingHand.parse('AA'),
          action: RangeAction.raise,
          frequency: 1,
        ),
      );
      final quiz = _quizWith(
        relatedRangeSpotId: 'test_spot',
        heroCards: ['Ah', 'Ac'],
        correctActionType: PokerActionType.raise,
      );

      await _pump(
        tester,
        quiz,
        repositoryOverride: _FakeRangeRepository(chart),
      );

      expect(find.byType(ActionFrequencyBar), findsOneWidget);
      expect(find.textContaining('AA'), findsWidgets);
      expect(find.text('Raise 100%'), findsOneWidget);
    });

    testWidgets('MIX ハンド（blend あり）は主・副の内訳をそのまま表示する', (tester) async {
      final chart = _chartWith(
        'JJ',
        RangeEntry(
          hand: StartingHand.parse('JJ'),
          action: RangeAction.mixed,
          frequency: 0.5,
          blend: const RangeActionBlend(
            primary: RangeAction.threeBet,
            primaryShare: 0.6,
            secondary: RangeAction.call,
          ),
        ),
      );
      // 正解の選択肢は「3Bet」寄り（raise にマップされる）。
      final quiz = _quizWith(
        relatedRangeSpotId: 'test_spot',
        heroCards: ['Jh', 'Jc'],
        correctActionType: PokerActionType.raise,
      );

      await _pump(
        tester,
        quiz,
        repositoryOverride: _FakeRangeRepository(chart),
      );

      expect(find.byType(ActionFrequencyBar), findsOneWidget);
      expect(find.text('Raise 60%'), findsOneWidget);
      expect(find.text('Call 40%'), findsOneWidget);
    });

    testWidgets('relatedRangeSpotId が無ければ頻度バーを表示しない', (tester) async {
      final quiz = _quizWith(
        heroCards: ['Ah', 'Ac'],
        correctActionType: PokerActionType.raise,
      );

      await _pump(tester, quiz);

      expect(find.byType(ActionFrequencyBar), findsNothing);
    });

    testWidgets('状況（ヒーローの2枚）が無ければ頻度バーを表示しない', (tester) async {
      final quiz = _quizWith(
        relatedRangeSpotId: 'test_spot',
        correctActionType: PokerActionType.raise,
      );

      await _pump(
        tester,
        quiz,
        repositoryOverride: _FakeRangeRepository(
          _chartWith(
            'AA',
            RangeEntry(
              hand: StartingHand.parse('AA'),
              action: RangeAction.raise,
              frequency: 1,
            ),
          ),
        ),
      );

      expect(find.byType(ActionFrequencyBar), findsNothing);
    });

    testWidgets('スポット ID がレンジ表に存在しなければ頻度バーを表示しない', (tester) async {
      final quiz = _quizWith(
        relatedRangeSpotId: 'unknown_spot',
        heroCards: ['Ah', 'Ac'],
        correctActionType: PokerActionType.raise,
      );

      await _pump(tester, quiz, repositoryOverride: _FakeRangeRepository(null));

      expect(find.byType(ActionFrequencyBar), findsNothing);
    });

    testWidgets('レンジ表のアクションが設問の正解と食い違うときは、'
        '矛盾した数字に見えるため頻度バーを表示しない', (tester) async {
      // レンジ表では Fold だが、設問側の正解は Raise
      // （relatedRangeSpotId が別の決断を指しているケースを模している）。
      final chart = _chartWith(
        'AA',
        RangeEntry(
          hand: StartingHand.parse('AA'),
          action: RangeAction.fold,
          frequency: 1,
        ),
      );
      final quiz = _quizWith(
        relatedRangeSpotId: 'test_spot',
        heroCards: ['Ah', 'Ac'],
        correctActionType: PokerActionType.raise,
      );

      await _pump(
        tester,
        quiz,
        repositoryOverride: _FakeRangeRepository(chart),
      );

      expect(find.byType(ActionFrequencyBar), findsNothing);
    });

    testWidgets('実際のクイズバンク・実際のレンジ表でも解決できる設問がある', (tester) async {
      // pf001: UTG の A9o は常に Fold で、6max_utg_open のレンジ表とも一致する
      // （モックのレンジ表をそのまま使い、フェイクに差し替えない統合的な確認）。
      final quiz = PreflopQuizzes.all.firstWhere((q) => q.id == 'pf001');

      await _pump(tester, quiz);

      expect(find.byType(ActionFrequencyBar), findsOneWidget);
      expect(find.text('Fold 100%'), findsOneWidget);
    });

    testWidgets('クイズバンク全体では、実データに基づく頻度バーが出る設問は一部だけ'
        '（0件でも全件でもない ── force-fit せず、一致するときだけ出す方針の回帰ガード）', (tester) async {
      // relatedRangeSpotId とヒーローの具体的な2枚が揃っている設問のうち、
      // 実際にレンジ表と正解の選択肢が一致してバーが出るのは一部だけになる。
      // これは `relatedRangeSpotId` が「その設問が問う決断そのもの」ではなく
      // 「参考になる関連チャート」を指すだけの設問（3Bet に直面した場面や
      // フロップの判断からオープンレイズ表を参照している設問など）が
      // 混ざっているため。
      final candidates = QuizBank.all.where(
        (quiz) =>
            quiz.explanation.relatedRangeSpotId != null &&
            quiz.situation != null &&
            quiz.situation!.heroCards.length == 2,
      );
      expect(candidates.length, 34);

      var shown = 0;
      for (final quiz in candidates) {
        await _pump(tester, quiz);
        if (find.byType(ActionFrequencyBar).evaluate().isNotEmpty) {
          shown++;
        }
      }

      expect(
        shown,
        greaterThanOrEqualTo(15),
        reason: '仕組みが機能していれば、一定数は実データで頻度バーが出るはずです',
      );
      expect(
        shown,
        lessThan(candidates.length),
        reason:
            '食い違う決断にまで無理に頻度バーを出してしまっています'
            '（force-fit しない方針に反します）',
      );
    });
  });
}
