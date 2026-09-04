import '../../../core/errors/friendly_error.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_gateway.dart';
import '../../hand_review/domain/hand_review_record.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../domain/learning_record.dart';
import '../domain/learning_stores.dart';
import '../domain/user_profile.dart';

/// 同期の結果。UI に「保存済み / 未同期 n 件」を出すために使う。
enum SyncPhase {
  /// まだ一度も同期していない。
  idle,

  /// 実行中。
  syncing,

  /// 全件 Supabase に入っている。
  synced,

  /// 通信できず、ローカルに溜めている。
  offline,

  /// 通信はできたが失敗した（RLS・スキーマ不整合など）。
  failed,
}

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;

  /// Supabase へ未送信の件数。
  final int pendingCount;
  final DateTime? lastSyncedAt;

  /// 失敗理由。UI にそのまま出せる日本語。
  final String? message;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// 同期 1 回ぶんの結果。
class SyncOutcome {
  const SyncOutcome({required this.status, required this.record});

  final SyncStatus status;

  /// 同期後の学習履歴。取得できなかったときはローカルのまま。
  final LearningRecord record;
}

/// ローカル保存と Supabase の橋渡し。
///
/// 書き込みは必ず「先にローカル → あとで Supabase」。
/// 圏外でもクイズは解けて、通信が戻ったときにまとめて送られる。
class LearningSyncService {
  const LearningSyncService({
    required this.local,
    required this.remote,
    required this.auth,
    this.initialPokerLevel = PokerLevel.novice,
  });

  final LocalLearningStore local;
  final RemoteLearningStore remote;
  final AuthGateway auth;

  /// サーバー側にまだプロフィールが無いときに作成する初期レベル。
  /// オンボーディングの回答があればそれを使う（`learning_providers.dart` で注入）。
  final PokerLevel initialPokerLevel;

  /// 1 回の送信で送る最大件数。
  static const _batchSize = 200;

  bool get isRemoteEnabled => remote.isEnabled;

  Future<LearningRecord> loadLocal() => local.loadRecord();

  Future<void> saveAttempt(QuizAttempt attempt) =>
      local.saveAttempt(StoredAttempt(attempt: attempt, synced: false));

  Future<void> saveReview(HandReviewRecord review) =>
      local.saveReview(StoredReview(review: review, synced: false));

  Future<int> pendingCount() async =>
      (await local.pendingAttempts()).length +
      (await local.pendingReviews()).length;

  /// 未送信ぶんを送り、サーバー側の履歴を取り込む。
  Future<SyncOutcome> synchronize() async {
    if (!remote.isEnabled) {
      return SyncOutcome(
        status: SyncStatus(
          phase: SyncPhase.offline,
          pendingCount: await pendingCount(),
          message: 'Supabase に接続していないため、この端末にだけ保存しています。',
        ),
        record: await local.loadRecord(),
      );
    }

    final user = auth.currentUser ?? await auth.ensureSignedIn();
    if (user == null) {
      return SyncOutcome(
        status: SyncStatus(
          phase: SyncPhase.offline,
          pendingCount: await pendingCount(),
          message: auth.lastFailure?.message ?? 'サインインできていないため同期を保留しています。',
        ),
        record: await local.loadRecord(),
      );
    }

    try {
      await _adoptOwner(user);
      await _pushPending(user.id);
      await _pullRemote(user.id);

      final record = await local.loadRecord();
      await _pushCategoryStats(user.id, record);

      return SyncOutcome(
        status: SyncStatus(
          phase: SyncPhase.synced,
          pendingCount: await pendingCount(),
          lastSyncedAt: DateTime.now(),
        ),
        record: record,
      );
    } catch (error) {
      return SyncOutcome(
        status: SyncStatus(
          phase: SyncPhase.failed,
          pendingCount: await pendingCount(),
          message: friendlyErrorMessage(
            error,
            offline: 'まだサーバーに同期できていません。この端末には保存されています。',
            fallback: '同期できませんでした。この端末には保存されています。',
          ),
        ),
        record: await local.loadRecord(),
      );
    }
  }

  /// プロフィール行を用意し、サーバー側の内容を返す。
  Future<UserProfile?> ensureProfile(AppUser user) async {
    if (!remote.isEnabled) return null;
    try {
      final existing = await remote.fetchProfile(user.id);
      if (existing != null) return existing;

      final created = UserProfile(
        id: user.id,
        displayName: 'プレイヤー',
        pokerLevel: initialPokerLevel,
        createdAt: DateTime.now(),
      );
      await remote.upsertProfile(created);
      return created;
    } catch (_) {
      // プロフィールが作れなくても学習は続けられる。
      return null;
    }
  }

  /// ローカルデータの持ち主を確認する。
  ///
  /// 匿名 → メール登録の昇格では user_id が変わらないので、そのまま引き継がれる。
  /// 別アカウントでログインしたときだけローカルを捨てて取り直す。
  Future<void> _adoptOwner(AppUser user) async {
    final owner = await local.ownerId();
    if (owner == user.id) return;
    if (owner != null) await local.clear();
    await local.setOwnerId(user.id);
  }

  Future<void> _pushPending(String userId) async {
    final attempts = await local.pendingAttempts();
    for (var i = 0; i < attempts.length; i += _batchSize) {
      final batch = attempts.sublist(
        i,
        (i + _batchSize).clamp(0, attempts.length),
      );
      await remote.pushAttempts(userId, batch);
      await local.markAttemptsSynced(batch.map((stored) => stored.clientId));
    }

    final reviews = await local.pendingReviews();
    for (var i = 0; i < reviews.length; i += _batchSize) {
      final batch = reviews.sublist(
        i,
        (i + _batchSize).clamp(0, reviews.length),
      );
      await remote.pushReviews(userId, batch);
      await local.markReviewsSynced(batch.map((stored) => stored.clientId));
    }
  }

  Future<void> _pullRemote(String userId) async {
    final snapshot = await remote.fetchAll(userId);
    await local.mergeRemote(
      attempts: snapshot.attempts,
      reviews: snapshot.reviews,
    );
  }

  Future<void> _pushCategoryStats(String userId, LearningRecord record) async {
    final byCategory = <String, (int, int)>{};
    for (final attempt in record.attempts) {
      final current = byCategory[attempt.category.id] ?? (0, 0);
      byCategory[attempt.category.id] = attempt.isCorrect
          ? (current.$1 + 1, current.$2)
          : (current.$1, current.$2 + 1);
    }
    await remote.pushCategoryStats(userId, byCategory);
  }
}
