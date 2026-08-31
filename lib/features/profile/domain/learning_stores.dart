import '../../hand_review/domain/hand_review_record.dart';
import '../../quiz/domain/quiz_attempt.dart';
import 'learning_record.dart';
import 'user_profile.dart';

/// 端末側で採番する同期キー。
///
/// 同じキーで再送しても Supabase 側で重複行にならないようにするための ID。
/// クイズは「同じ問題・同じ日は 1 件」という既存仕様に合わせて決定的に作る。
String attemptClientId(QuizAttempt attempt) {
  final day = attempt.answeredAt;
  final date =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return '${attempt.quizId}@$date';
}

/// ローカルに保持しているクイズ回答 1 件。
class StoredAttempt {
  const StoredAttempt({required this.attempt, required this.synced});

  final QuizAttempt attempt;

  /// Supabase へ送信済みか。false のものが同期待ちキュー。
  final bool synced;

  String get clientId => attemptClientId(attempt);
}

/// ローカルに保持しているハンドレビュー 1 件。
class StoredReview {
  const StoredReview({required this.review, required this.synced});

  final HandReviewRecord review;
  final bool synced;

  String get clientId => review.id;
}

/// 端末内の学習履歴。オフラインでもここだけで完結して動く。
abstract class LocalLearningStore {
  /// 画面に出すための全履歴。
  Future<LearningRecord> loadRecord();

  Future<void> saveAttempt(StoredAttempt attempt);

  Future<void> saveReview(StoredReview review);

  /// 未送信のもの（古い順）。
  Future<List<StoredAttempt>> pendingAttempts();

  Future<List<StoredReview>> pendingReviews();

  Future<void> markAttemptsSynced(Iterable<String> clientIds);

  Future<void> markReviewsSynced(Iterable<String> clientIds);

  /// Supabase から取得した履歴を取り込む（送信済みとして保存する）。
  Future<void> mergeRemote({
    required List<QuizAttempt> attempts,
    required List<HandReviewRecord> reviews,
  });

  /// このローカルデータの持ち主の user_id。別ユーザーでログインしたら作り直す。
  Future<String?> ownerId();

  Future<void> setOwnerId(String userId);

  Future<void> clear();
}

/// Supabase から取ってきた履歴のまとまり。
class RemoteSnapshot {
  const RemoteSnapshot({required this.attempts, required this.reviews});

  const RemoteSnapshot.empty() : attempts = const [], reviews = const [];

  final List<QuizAttempt> attempts;
  final List<HandReviewRecord> reviews;
}

/// Supabase 側の読み書き。通信できないときは例外を投げてよい（同期側で拾う）。
abstract class RemoteLearningStore {
  /// 通信可能な実装かどうか。false ならローカルのみで動作する。
  bool get isEnabled;

  Future<RemoteSnapshot> fetchAll(String userId);

  Future<void> pushAttempts(String userId, List<StoredAttempt> attempts);

  Future<void> pushReviews(String userId, List<StoredReview> reviews);

  /// カテゴリ別の集計をサーバー側にも持たせる（`learning_stats`）。
  Future<void> pushCategoryStats(String userId, Map<String, (int, int)> stats);

  Future<UserProfile?> fetchProfile(String userId);

  Future<void> upsertProfile(UserProfile profile);
}

/// 通信しないダミー。テストと、Supabase 未初期化時に使う。
class NoopRemoteLearningStore implements RemoteLearningStore {
  const NoopRemoteLearningStore();

  @override
  bool get isEnabled => false;

  @override
  Future<RemoteSnapshot> fetchAll(String userId) async =>
      const RemoteSnapshot.empty();

  @override
  Future<void> pushAttempts(
    String userId,
    List<StoredAttempt> attempts,
  ) async {}

  @override
  Future<void> pushReviews(String userId, List<StoredReview> reviews) async {}

  @override
  Future<void> pushCategoryStats(
    String userId,
    Map<String, (int, int)> stats,
  ) async {}

  @override
  Future<UserProfile?> fetchProfile(String userId) async => null;

  @override
  Future<void> upsertProfile(UserProfile profile) async {}
}
