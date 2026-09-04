import 'package:ai_poker_coach/features/onboarding/application/onboarding_providers.dart';
import 'package:ai_poker_coach/features/onboarding/domain/onboarding_answers.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedOnboardingAnswersNotifier extends OnboardingAnswersNotifier {
  _FixedOnboardingAnswersNotifier(this._value);

  final OnboardingAnswers? _value;

  @override
  OnboardingAnswers? build() => _value;
}

void main() {
  group('ProfileStore とオンボーディングの連動', () {
    test('オンボーディング未完了なら初級者がデフォルト', () {
      final container = ProviderContainer(
        overrides: [
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(userProfileProvider).pokerLevel, PokerLevel.novice);
    });

    test('オンボーディングで選んだレベルがプロフィールの初期値になる', () {
      final container = ProviderContainer(
        overrides: [
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(
              OnboardingAnswers(
                pokerLevel: PokerLevel.advanced,
                focusCategories: const [],
                completedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(userProfileProvider).pokerLevel,
        PokerLevel.advanced,
      );
    });

    test('apply() で上書きした後は、それが優先される', () {
      final container = ProviderContainer(
        overrides: [
          onboardingAnswersProvider.overrideWith(
            () => _FixedOnboardingAnswersNotifier(
              OnboardingAnswers(
                pokerLevel: PokerLevel.advanced,
                focusCategories: const [],
                completedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final current = container.read(userProfileProvider);
      container
          .read(profileStoreProvider.notifier)
          .apply(
            UserProfile(
              id: current.id,
              displayName: current.displayName,
              pokerLevel: PokerLevel.beginner,
              createdAt: current.createdAt,
            ),
          );

      expect(
        container.read(userProfileProvider).pokerLevel,
        PokerLevel.beginner,
      );
    });
  });
}
