import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/onboarding/domain/onboarding_answers.dart';
import 'package:ai_poker_coach/features/onboarding/infrastructure/onboarding_store.dart';
import 'package:ai_poker_coach/features/profile/domain/user_profile.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingStore', () {
    test('未回答なら null を返す', () async {
      final store = OnboardingStore(InMemoryKeyValueStore());
      expect(await store.load(), isNull);
    });

    test('保存した内容をそのまま読み戻せる（ラウンドトリップ）', () async {
      final store = OnboardingStore(InMemoryKeyValueStore());
      final answers = OnboardingAnswers(
        pokerLevel: PokerLevel.intermediate,
        focusCategories: const [QuizCategory.flop, QuizCategory.turn],
        completedAt: DateTime(2026, 3, 2, 9, 30),
      );

      await store.save(answers);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.pokerLevel, PokerLevel.intermediate);
      expect(loaded.focusCategories, [QuizCategory.flop, QuizCategory.turn]);
      expect(loaded.completedAt, answers.completedAt);
    });

    test('clear() で未回答状態に戻る', () async {
      final store = OnboardingStore(InMemoryKeyValueStore());
      await store.save(
        OnboardingAnswers(
          pokerLevel: PokerLevel.beginner,
          focusCategories: const [QuizCategory.preflop],
          completedAt: DateTime.now(),
        ),
      );
      expect(await store.load(), isNotNull);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('壊れたJSONは未回答として扱う', () async {
      final kv = InMemoryKeyValueStore();
      await kv.setString('onboarding.answers.v1', '{not valid json');
      final store = OnboardingStore(kv);
      expect(await store.load(), isNull);
    });

    test('未知のカテゴリIDが混じっていても他は読み込める', () async {
      final kv = InMemoryKeyValueStore();
      await kv.setString(
        'onboarding.answers.v1',
        '{"poker_level":"novice","focus_categories":["preflop","made_up"],'
            '"completed_at":"2026-01-01T00:00:00.000Z"}',
      );
      final store = OnboardingStore(kv);
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.focusCategories, [QuizCategory.preflop]);
    });
  });

  group('OnboardingAnswers.fromJson', () {
    test('必須フィールドが欠けていれば null', () {
      expect(OnboardingAnswers.fromJson(const {}), isNull);
      expect(
        OnboardingAnswers.fromJson(const {'poker_level': 'novice'}),
        isNull,
      );
    });

    test('未知のレベルIDなら null', () {
      expect(
        OnboardingAnswers.fromJson(const {
          'poker_level': 'grandmaster',
          'completed_at': '2026-01-01T00:00:00.000Z',
        }),
        isNull,
      );
    });
  });
}
