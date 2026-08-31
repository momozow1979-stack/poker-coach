import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/date_x.dart';
import '../../auth/application/auth_providers.dart';
import '../../hand_review/domain/hand_review_record.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../domain/learning_record.dart';
import '../domain/learning_stats.dart';
import '../domain/learning_stores.dart';
import '../domain/user_profile.dart';
import '../infrastructure/json_learning_store.dart';
import '../infrastructure/learning_sync_service.dart';
import '../infrastructure/mock_learning_seed.dart';

/// 端末側の保存先。`main()` で shared_preferences 版に差し替える。
/// 既定はメモリ上のみ（テストではこれで十分）。
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => InMemoryKeyValueStore(),
);

final localLearningStoreProvider = Provider<LocalLearningStore>(
  (ref) => JsonLearningStore(ref.watch(keyValueStoreProvider)),
);

/// Supabase 側の保存先。既定は通信しない実装。
final remoteLearningStoreProvider = Provider<RemoteLearningStore>(
  (ref) => const NoopRemoteLearningStore(),
);

final learningSyncServiceProvider = Provider<LearningSyncService>(
  (ref) => LearningSyncService(
    local: ref.watch(localLearningStoreProvider),
    remote: ref.watch(remoteLearningStoreProvider),
    auth: ref.watch(authGatewayProvider),
  ),
);

/// 学習履歴の唯一の保存場所。
///
/// 状態は「ローカル保存の写し」。書き込みは
/// 画面反映（即時） → ローカル保存 → Supabase 送信 の順に流れる。
/// Notifier のインターフェース（[recordAttempt] / [recordReview]）は
/// Phase 2 までと同じなので、プレゼンテーション層は変更していない。
class LearningStore extends Notifier<LearningRecord> {
  @override
  LearningRecord build() => const LearningRecord();

  /// 同期側から読み込んだ内容で置き換える。
  void replace(LearningRecord record) => state = record;

  /// クイズの回答を記録する。同じ問題への再回答は上書きする。
  void recordAttempt(QuizAttempt attempt) {
    final attempts = [
      ...state.attempts.where(
        (existing) =>
            !(existing.quizId == attempt.quizId &&
                existing.answeredAt.isSameDay(attempt.answeredAt)),
      ),
      attempt,
    ];
    state = state.copyWith(
      attempts: attempts,
      activeDays: {...state.activeDays, attempt.answeredAt.dateOnly},
    );
    unawaited(
      ref.read(learningSyncControllerProvider.notifier).saveAttempt(attempt),
    );
  }

  /// ハンドレビューの結果を保存する。
  void recordReview(HandReviewRecord review) {
    state = state.copyWith(
      reviews: [review, ...state.reviews],
      activeDays: {...state.activeDays, review.createdAt.dateOnly},
    );
    unawaited(
      ref.read(learningSyncControllerProvider.notifier).saveReview(review),
    );
  }
}

final learningStoreProvider = NotifierProvider<LearningStore, LearningRecord>(
  LearningStore.new,
);

/// ローカル保存 → Supabase 同期の司令塔。
///
/// 保存と同期を 1 本のキューに直列化しているので、
/// 「同期中に回答した 1 問が同期後の状態で消える」が起きない。
class LearningSyncController extends Notifier<SyncStatus> {
  Future<void> _queue = Future<void>.value();
  Timer? _retryTimer;
  bool _syncing = false;

  /// 未送信ぶんの再送間隔。
  static const retryInterval = Duration(seconds: 60);

  @override
  SyncStatus build() {
    ref.onDispose(() => _retryTimer?.cancel());
    return const SyncStatus();
  }

  LearningSyncService get _service => ref.read(learningSyncServiceProvider);

  /// 起動時: ローカルを読んで画面に出し、その後に裏で同期する。
  Future<void> bootstrap() async {
    await _enqueue(() async {
      if (AppConfig.useMockSeed) await _seedForDebug();
      final record = await _service.loadLocal();
      final pending = await _service.pendingCount();
      if (!ref.mounted) return;
      ref.read(learningStoreProvider.notifier).replace(record);
      state = state.copyWith(pendingCount: pending);
    });
    unawaited(syncNow());
  }

  Future<void> saveAttempt(QuizAttempt attempt) async {
    await _enqueue(() async {
      await _service.saveAttempt(attempt);
      final pending = await _service.pendingCount();
      if (!ref.mounted) return;
      state = state.copyWith(pendingCount: pending);
    });
    unawaited(syncNow());
  }

  Future<void> saveReview(HandReviewRecord review) async {
    await _enqueue(() async {
      await _service.saveReview(review);
      final pending = await _service.pendingCount();
      if (!ref.mounted) return;
      state = state.copyWith(pendingCount: pending);
    });
    unawaited(syncNow());
  }

  /// 未送信ぶんを送り、サーバー側の履歴を取り込む。
  Future<void> syncNow() async {
    if (!ref.mounted) return;
    if (!_service.isRemoteEnabled) {
      state = state.copyWith(
        phase: SyncPhase.offline,
        message: 'Supabase に接続していないため、この端末にだけ保存しています。',
      );
      return;
    }
    if (_syncing) return;
    _syncing = true;
    _retryTimer?.cancel();
    state = state.copyWith(phase: SyncPhase.syncing, clearMessage: true);

    try {
      await _enqueue(() async {
        final outcome = await _service.synchronize();
        if (!ref.mounted) return;
        ref.read(learningStoreProvider.notifier).replace(outcome.record);
        state = outcome.status;
      });
      await _refreshProfile();
    } finally {
      _syncing = false;
    }
    if (ref.mounted) _scheduleRetryIfNeeded();
  }

  Future<void> _refreshProfile() async {
    if (!ref.mounted) return;
    // 直前の同期でサインインした直後は accountProvider にまだ届いていないことが
    // あるため、認証の実装から直接取る。
    final user = ref.read(authGatewayProvider).currentUser;
    if (user == null) return;
    final profile = await _service.ensureProfile(user);
    if (profile == null || !ref.mounted) return;
    ref.read(profileStoreProvider.notifier).apply(profile);
  }

  /// 未送信が残っているうちは、一定間隔で送り直す。
  void _scheduleRetryIfNeeded() {
    _retryTimer?.cancel();
    if (state.phase == SyncPhase.synced && state.pendingCount == 0) return;
    _retryTimer = Timer(retryInterval, syncNow);
  }

  /// 保存と同期を直列に流すためのキュー。
  ///
  /// 例外はここで飲み込む（呼び出し側は fire-and-forget のため）。
  /// 送信できなかったぶんはローカルに未送信のまま残り、次回まとめて再送される。
  Future<void> _enqueue(Future<void> Function() action) {
    final completer = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        if (ref.mounted) await action();
      } catch (error) {
        if (ref.mounted) {
          state = state.copyWith(
            phase: SyncPhase.failed,
            message: '保存に失敗しました（$error）。',
          );
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// デバッグ用のダミー履歴。`--dart-define=USE_MOCK_SEED=true` のときだけ動く。
  Future<void> _seedForDebug() async {
    final local = ref.read(localLearningStoreProvider);
    final existing = await local.loadRecord();
    if (existing.attempts.isNotEmpty) return;
    for (final attempt in MockLearningSeed.build().attempts) {
      await local.saveAttempt(StoredAttempt(attempt: attempt, synced: true));
    }
  }
}

final learningSyncControllerProvider =
    NotifierProvider<LearningSyncController, SyncStatus>(
      LearningSyncController.new,
    );

/// 起動時のローカル読み込み。完了するまで画面を出さない。
final learningBootstrapProvider = FutureProvider<void>(
  (ref) => ref.read(learningSyncControllerProvider.notifier).bootstrap(),
);

/// 学習履歴から算出した集計値。
final learningStatsProvider = Provider<LearningStats>((ref) {
  final record = ref.watch(learningStoreProvider);
  final now = DateTime.now();
  final last7 = now.subtract(const Duration(days: 7));
  final last30 = now.subtract(const Duration(days: 30));

  return LearningStats(
    attempts: record.attempts,
    reviewCount: record.reviews.length,
    streakDays: calculateStreak(record.activeDays),
    activeDaysLast7: record.activeDays
        .where((day) => day.isAfter(last7))
        .length,
    activeDaysLast30: record.activeDays
        .where((day) => day.isAfter(last30))
        .length,
  );
});

/// レビュー履歴（新しい順）。
final handReviewHistoryProvider = Provider<List<HandReviewRecord>>(
  (ref) => ref.watch(learningStoreProvider).reviews,
);

/// ログインユーザーのプロフィール。Supabase の `profiles` を取れたら差し替わる。
class ProfileStore extends Notifier<UserProfile> {
  @override
  UserProfile build() => UserProfile(
    id: 'local',
    displayName: 'プレイヤー',
    pokerLevel: PokerLevel.novice,
    createdAt: DateTime.now(),
  );

  void apply(UserProfile profile) => state = profile;
}

final profileStoreProvider = NotifierProvider<ProfileStore, UserProfile>(
  ProfileStore.new,
);

final userProfileProvider = Provider<UserProfile>(
  (ref) => ref.watch(profileStoreProvider),
);
