import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stores.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/json_learning_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  final today = DateTime(2026, 8, 31, 20);

  group('JsonLearningStore', () {
    test('保存した回答はストアを作り直しても残る（＝再起動しても消えない）', () async {
      final storage = InMemoryKeyValueStore();
      final store = JsonLearningStore(storage);

      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'preflop-001', answeredAt: today),
          synced: false,
        ),
      );
      await store.saveReview(
        StoredReview(
          review: fakeReview(id: 'review-1', createdAt: today),
          synced: false,
        ),
      );

      // アプリを起動し直した状況を、同じ保存領域の新しいインスタンスで再現する。
      final reopened = JsonLearningStore(storage);
      final record = await reopened.loadRecord();

      expect(record.attempts, hasLength(1));
      expect(record.attempts.single.quizId, 'preflop-001');
      expect(record.reviews, hasLength(1));
      expect(record.reviews.single.result.score, 72);
      expect(record.activeDays, contains(DateTime(2026, 8, 31)));
    });

    test('同じ問題に同じ日に答え直すと上書きされる', () async {
      final store = JsonLearningStore(InMemoryKeyValueStore());

      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(
            quizId: 'preflop-001',
            answeredAt: today,
            isCorrect: false,
          ),
          synced: false,
        ),
      );
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(
            quizId: 'preflop-001',
            answeredAt: today.add(const Duration(minutes: 5)),
          ),
          synced: false,
        ),
      );

      final record = await store.loadRecord();
      expect(record.attempts, hasLength(1));
      expect(record.attempts.single.isCorrect, isTrue);
    });

    test('別の日の同じ問題は別レコードになる', () async {
      final store = JsonLearningStore(InMemoryKeyValueStore());

      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'preflop-001', answeredAt: today),
          synced: false,
        ),
      );
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(
            quizId: 'preflop-001',
            answeredAt: today.subtract(const Duration(days: 1)),
          ),
          synced: false,
        ),
      );

      expect((await store.loadRecord()).attempts, hasLength(2));
    });

    test('未送信ぶんだけが同期キューに乗り、送信済みにすると消える', () async {
      final store = JsonLearningStore(InMemoryKeyValueStore());

      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'q1', answeredAt: today),
          synced: false,
        ),
      );
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'q2', answeredAt: today),
          synced: true,
        ),
      );

      final pending = await store.pendingAttempts();
      expect(pending.map((stored) => stored.attempt.quizId), ['q1']);

      await store.markAttemptsSynced(['q1@2026-08-31']);
      expect(await store.pendingAttempts(), isEmpty);
    });

    test('サーバーの履歴を取り込んでも、未送信のローカル分は消えない', () async {
      final store = JsonLearningStore(InMemoryKeyValueStore());
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(
            quizId: 'local-only',
            answeredAt: today,
            isCorrect: false,
          ),
          synced: false,
        ),
      );

      await store.mergeRemote(
        attempts: [
          fakeAttempt(
            quizId: 'from-server',
            answeredAt: today.subtract(const Duration(days: 2)),
          ),
        ],
        reviews: [
          fakeReview(
            id: 'server-review',
            createdAt: today.subtract(const Duration(days: 2)),
          ),
        ],
      );

      final record = await store.loadRecord();
      expect(
        record.attempts.map((attempt) => attempt.quizId),
        containsAll(<String>['local-only', 'from-server']),
      );
      expect(record.reviews.single.id, 'server-review');
      expect(
        (await store.pendingAttempts()).single.attempt.quizId,
        'local-only',
      );
    });

    test('持ち主が変わったら clear でローカルを捨てられる', () async {
      final store = JsonLearningStore(InMemoryKeyValueStore());
      await store.setOwnerId('user-a');
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'q1', answeredAt: today),
          synced: true,
        ),
      );

      expect(await store.ownerId(), 'user-a');
      await store.clear();
      expect((await store.loadRecord()).attempts, isEmpty);
    });

    test('壊れた行があっても、残りの履歴は読める', () async {
      final storage = InMemoryKeyValueStore();
      final store = JsonLearningStore(storage);
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'q1', answeredAt: today),
          synced: true,
        ),
      );

      final rows = (await storage.getStringList('learning.attempts.v1'))!;
      await storage.setStringList('learning.attempts.v1', [
        'これは JSON ではない',
        '{"quiz_key": null}',
        ...rows,
      ]);

      final record = await JsonLearningStore(storage).loadRecord();
      expect(record.attempts.map((attempt) => attempt.quizId), ['q1']);
    });

    test('上限を超えたら古い送信済みから捨てるが、未送信は必ず残す', () async {
      const limit = 50;
      final store = JsonLearningStore(
        InMemoryKeyValueStore(),
        maxAttempts: limit,
      );
      final oldest = today.subtract(const Duration(days: 400));

      // 一番古い 1 件だけ未送信にしておく。
      await store.saveAttempt(
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'oldest', answeredAt: oldest),
          synced: false,
        ),
      );
      for (var i = 0; i < limit + 10; i++) {
        await store.saveAttempt(
          StoredAttempt(
            attempt: fakeAttempt(
              quizId: 'q$i',
              answeredAt: oldest.add(Duration(minutes: i + 1)),
            ),
            synced: true,
          ),
        );
      }

      final record = await store.loadRecord();
      expect(record.attempts, hasLength(limit));
      expect(
        record.attempts.map((attempt) => attempt.quizId),
        contains('oldest'),
      );
    });
  });
}
