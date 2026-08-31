import 'package:ai_poker_coach/core/storage/key_value_store.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stores.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/json_learning_store.dart';
import 'package:ai_poker_coach/features/profile/infrastructure/learning_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  final today = DateTime(2026, 8, 31, 20);

  ({
    LearningSyncService service,
    JsonLearningStore local,
    FakeRemoteLearningStore remote,
    FakeAuthGateway auth,
  })
  build({bool remoteEnabled = true}) {
    final local = JsonLearningStore(InMemoryKeyValueStore());
    final remote = FakeRemoteLearningStore(enabled: remoteEnabled);
    final auth = FakeAuthGateway();
    addTearDown(auth.dispose);
    return (
      service: LearningSyncService(local: local, remote: remote, auth: auth),
      local: local,
      remote: remote,
      auth: auth,
    );
  }

  group('LearningSyncService', () {
    test('保存 → 同期で Supabase に送られ、未送信が 0 になる', () async {
      final env = build();

      await env.service.saveAttempt(
        fakeAttempt(quizId: 'preflop-001', answeredAt: today),
      );
      expect(await env.service.pendingCount(), 1);

      final outcome = await env.service.synchronize();

      expect(outcome.status.phase, SyncPhase.synced);
      expect(outcome.status.pendingCount, 0);
      expect(env.remote.attemptsOf(env.auth.currentUser!.id), hasLength(1));
    });

    test('圏外では送信されず、ローカルに溜まる。復帰したらまとめて送られる', () async {
      final env = build();
      env.remote.offline = true;

      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q1', answeredAt: today),
      );
      await env.service.saveReview(fakeReview(id: 'r1', createdAt: today));

      final failed = await env.service.synchronize();
      expect(failed.status.phase, SyncPhase.failed);
      expect(failed.status.pendingCount, 2);
      // 画面に出す履歴はローカルから作られるので、圏外でも消えない。
      expect(failed.record.attempts, hasLength(1));
      expect(failed.record.reviews, hasLength(1));

      env.remote.offline = false;
      final recovered = await env.service.synchronize();

      expect(recovered.status.phase, SyncPhase.synced);
      expect(recovered.status.pendingCount, 0);
      final userId = env.auth.currentUser!.id;
      expect(env.remote.attemptsOf(userId), hasLength(1));
      expect(env.remote.reviewsOf(userId), hasLength(1));
    });

    test('同じ内容を二度送っても Supabase 側で重複しない', () async {
      final env = build();
      final attempt = fakeAttempt(quizId: 'q1', answeredAt: today);

      await env.service.saveAttempt(attempt);
      await env.service.synchronize();
      // 送信済みフラグを無視して、もう一度同じものを送る状況を作る。
      await env.service.saveAttempt(attempt);
      await env.service.synchronize();

      expect(env.remote.attemptsOf(env.auth.currentUser!.id), hasLength(1));
      expect(env.remote.pushAttemptCount, 2);
    });

    test('サーバーにある履歴が端末へ取り込まれる（別端末からの引き継ぎ）', () async {
      final env = build();
      await env.auth.ensureSignedIn();
      final userId = env.auth.currentUser!.id;

      await env.remote.pushAttempts(userId, [
        StoredAttempt(
          attempt: fakeAttempt(quizId: 'from-other-device', answeredAt: today),
          synced: true,
        ),
      ]);

      final outcome = await env.service.synchronize();
      expect(
        outcome.record.attempts.map((attempt) => attempt.quizId),
        contains('from-other-device'),
      );
    });

    test('匿名からメール登録に昇格しても、user_id が同じなら履歴は消えない', () async {
      final env = build();
      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q1', answeredAt: today),
      );
      await env.service.synchronize();

      await env.auth.registerEmail(
        email: 'player@example.com',
        password: 'password',
      );
      final outcome = await env.service.synchronize();

      expect(outcome.record.attempts, hasLength(1));
      expect(outcome.status.phase, SyncPhase.synced);
    });

    test('別アカウントでログインしたら、端末の履歴は入れ替わる', () async {
      final env = build();
      await env.service.saveAttempt(
        fakeAttempt(quizId: 'anon-q', answeredAt: today),
      );
      await env.service.synchronize();

      await env.auth.signIn(email: 'other@example.com', password: 'password');
      final outcome = await env.service.synchronize();

      expect(outcome.record.attempts, isEmpty);
    });

    test('カテゴリ別の集計が learning_stats へ送られる', () async {
      final env = build();
      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q1', answeredAt: today),
      );
      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q2', answeredAt: today, isCorrect: false),
      );
      await env.service.synchronize();

      expect(env.remote.categoryStats['preflop'], (1, 1));
    });

    test('匿名サインインが無効なら、保留にして理由を伝える', () async {
      final env = build();
      env.auth.anonymousSignInEnabled = false;

      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q1', answeredAt: today),
      );
      final outcome = await env.service.synchronize();

      expect(outcome.status.phase, SyncPhase.offline);
      expect(outcome.status.message, contains('Anonymous sign-ins'));
      expect(outcome.record.attempts, hasLength(1));
    });

    test('Supabase 未接続でも、ローカルだけで履歴は残る', () async {
      final env = build(remoteEnabled: false);

      await env.service.saveAttempt(
        fakeAttempt(quizId: 'q1', answeredAt: today),
      );
      final outcome = await env.service.synchronize();

      expect(outcome.status.phase, SyncPhase.offline);
      expect(outcome.record.attempts, hasLength(1));
    });
  });
}
