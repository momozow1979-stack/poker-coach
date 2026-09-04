import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/onboarding/domain/onboarding_answers.dart';
import 'package:ai_poker_coach/features/onboarding/infrastructure/onboarding_store.dart';
import 'package:ai_poker_coach/features/profile/domain/user_profile.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';

/// テスト用の既定回答。
///
/// `AiPokerCoachApp` を丸ごと pump するテストは、オンボーディング未完了だと
/// `/onboarding` へリダイレクトされてタブが出てこない。既存の全画面テストは
/// オンボーディング導入前の動線を検証しているため、pump 前にこのヘルパーで
/// 「オンボーディング完了済み」の状態を [KeyValueStore] に注入する。
OnboardingAnswers fakeOnboardingAnswers({
  PokerLevel pokerLevel = PokerLevel.novice,
  List<QuizCategory> focusCategories = const [QuizCategory.preflop],
}) => OnboardingAnswers(
  pokerLevel: pokerLevel,
  focusCategories: focusCategories,
  completedAt: DateTime(2026, 1, 1),
);

/// [store]（省略時は新しい [InMemoryKeyValueStore]）にオンボーディング完了済みの
/// 回答をあらかじめ保存してから返す。
///
/// `keyValueStoreProvider.overrideWithValue(...)` にそのまま渡せる。
Future<KeyValueStore> onboardingCompletedKeyValueStore({
  KeyValueStore? store,
  OnboardingAnswers? answers,
}) async {
  final resolved = store ?? InMemoryKeyValueStore();
  await OnboardingStore(resolved).save(answers ?? fakeOnboardingAnswers());
  return resolved;
}
