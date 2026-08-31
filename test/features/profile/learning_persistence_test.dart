import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/auth/application/auth_providers.dart';
import 'package:ai_poker_coach/features/profile/application/learning_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_record.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/learning_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

/// 「アプリを起動した」1 回ぶんを表す。dispose すると終了に相当する。
ProviderContainer bootContainer({
  required KeyValueStore storage,
  FakeRemoteLearningStore? remote,
  FakeAuthGateway? auth,
}) {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(storage),
      if (remote != null) remoteLearningStoreProvider.overrideWithValue(remote),
      if (auth != null) authGatewayProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<LearningRecord> boot(ProviderContainer container) async {
  await container.read(learningBootstrapProvider.future);
  await pumpEventQueue();
  return container.read(learningStoreProvider);
}

void main() {
  final today = DateTime(2026, 8, 31, 20);

  group('学習履歴の永続化', () {
    test('初回起動は空。モックの偽データは入らない', () async {
      final record = await boot(
        bootContainer(storage: InMemoryKeyValueStore()),
      );

      expect(record.attempts, isEmpty);
      expect(record.reviews, isEmpty);
      expect(record.activeDays, isEmpty);
    });

    test('回答したあと起動し直しても履歴が残る', () async {
      final storage = InMemoryKeyValueStore();

      final first = bootContainer(storage: storage);
      await boot(first);
      first
          .read(learningStoreProvider.notifier)
          .recordAttempt(fakeAttempt(quizId: 'preflop-001', answeredAt: today));
      await pumpEventQueue();
      first.dispose();

      // 2 回目の起動。保存領域だけが引き継がれる。
      final record = await boot(bootContainer(storage: storage));

      expect(record.attempts.map((attempt) => attempt.quizId), ['preflop-001']);
      expect(record.activeDays, contains(DateTime(2026, 8, 31)));
    });

    test('レビューも起動し直したあとに残る', () async {
      final storage = InMemoryKeyValueStore();

      final first = bootContainer(storage: storage);
      await boot(first);
      first
          .read(learningStoreProvider.notifier)
          .recordReview(fakeReview(id: 'review-1', createdAt: today));
      await pumpEventQueue();
      first.dispose();

      final record = await boot(bootContainer(storage: storage));
      expect(record.reviews.map((review) => review.id), ['review-1']);
      expect(record.reviews.single.input.heroHand, hasLength(2));
    });

    test('Supabase に繋がっていれば、回答が送信されて未同期 0 になる', () async {
      final remote = FakeRemoteLearningStore();
      final auth = FakeAuthGateway();
      addTearDown(auth.dispose);

      final container = bootContainer(
        storage: InMemoryKeyValueStore(),
        remote: remote,
        auth: auth,
      );
      await boot(container);

      container
          .read(learningStoreProvider.notifier)
          .recordAttempt(fakeAttempt(quizId: 'preflop-001', answeredAt: today));
      await pumpEventQueue();
      await container.read(learningSyncControllerProvider.notifier).syncNow();

      final status = container.read(learningSyncControllerProvider);
      expect(status.phase, SyncPhase.synced);
      expect(status.pendingCount, 0);
      expect(remote.attemptsOf(auth.currentUser!.id), hasLength(1));
    });

    test('圏外で回答したぶんは未同期として数えられる', () async {
      final remote = FakeRemoteLearningStore()..offline = true;
      final auth = FakeAuthGateway();
      addTearDown(auth.dispose);

      final container = bootContainer(
        storage: InMemoryKeyValueStore(),
        remote: remote,
        auth: auth,
      );
      await boot(container);

      container
          .read(learningStoreProvider.notifier)
          .recordAttempt(fakeAttempt(quizId: 'preflop-001', answeredAt: today));
      await pumpEventQueue();
      await container.read(learningSyncControllerProvider.notifier).syncNow();

      expect(container.read(learningSyncControllerProvider).pendingCount, 1);
      // 画面上の履歴は残っている。
      expect(container.read(learningStoreProvider).attempts, hasLength(1));
    });

    test('Supabase 未接続なら「この端末にだけ保存」と伝える', () async {
      final container = bootContainer(storage: InMemoryKeyValueStore());
      await boot(container);
      await container.read(learningSyncControllerProvider.notifier).syncNow();

      final status = container.read(learningSyncControllerProvider);
      expect(status.phase, SyncPhase.offline);
      expect(status.message, contains('この端末'));
    });
  });
}
