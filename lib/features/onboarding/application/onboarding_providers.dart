import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/learning_providers.dart';
import '../domain/onboarding_answers.dart';
import '../infrastructure/onboarding_store.dart';

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => OnboardingStore(ref.watch(keyValueStoreProvider)),
);

/// オンボーディングの回答。未完了（未読み込み含む）なら null。
///
/// [onboardingBootstrapProvider] が起動時にローカルの保存内容で
/// この状態を差し替える。`router.dart` の `redirect` はこの値を
/// 「完了しているかどうか」の判定に使う。
class OnboardingAnswersNotifier extends Notifier<OnboardingAnswers?> {
  @override
  OnboardingAnswers? build() => null;

  /// 起動時の読み込み結果で置き換える。
  void replace(OnboardingAnswers? answers) => state = answers;

  /// オンボーディングを完了する。保存してから状態を更新する。
  Future<void> complete(OnboardingAnswers answers) async {
    await ref.read(onboardingStoreProvider).save(answers);
    state = answers;
  }
}

final onboardingAnswersProvider =
    NotifierProvider<OnboardingAnswersNotifier, OnboardingAnswers?>(
      OnboardingAnswersNotifier.new,
    );

/// 起動時: ローカルに保存済みの回答を読み込む。
///
/// `learningBootstrapProvider` と同じ形で、これが終わるまで
/// アプリ本体（と `router` のリダイレクト判定）を出さない。
final onboardingBootstrapProvider = FutureProvider<void>((ref) async {
  final answers = await ref.read(onboardingStoreProvider).load();
  ref.read(onboardingAnswersProvider.notifier).replace(answers);
});
