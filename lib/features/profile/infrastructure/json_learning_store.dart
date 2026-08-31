import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/date_x.dart';
import '../../hand_review/domain/hand_review_record.dart';
import '../../quiz/domain/quiz_attempt.dart';
import '../domain/learning_record.dart';
import '../domain/learning_stores.dart';
import 'learning_json.dart';

/// [KeyValueStore] の上に載せた学習履歴のローカル保存。
///
/// 1 レコード = 1 行の JSON として持つ。全件を 1 個の巨大な JSON にしないことで、
/// 破損した行を捨てて残りを読めるようにしている。
///
/// Supabase が正本で、ここは「オフラインでも壊れないためのキャッシュ + 送信キュー」。
/// そのため古いものから [maxAttempts] / [maxReviews] で打ち切る。
/// ただし未送信のものは件数に関係なく必ず残す。
class JsonLearningStore implements LocalLearningStore {
  JsonLearningStore(
    this._store, {
    this.maxAttempts = defaultMaxAttempts,
    this.maxReviews = defaultMaxReviews,
  });

  final KeyValueStore _store;

  /// 端末に残すクイズ回答の上限。1 日 10 問なら 1 年半ぶん。
  final int maxAttempts;
  final int maxReviews;

  static const _attemptsKey = 'learning.attempts.v1';
  static const _reviewsKey = 'learning.reviews.v1';
  static const _ownerKey = 'learning.owner_id.v1';

  static const defaultMaxAttempts = 5000;
  static const defaultMaxReviews = 300;

  /// 読み込み済みのキャッシュ。null なら未読み込み。
  Map<String, StoredAttempt>? _attempts;
  List<StoredReview>? _reviews;

  Future<Map<String, StoredAttempt>> _loadAttempts() async {
    final cached = _attempts;
    if (cached != null) return cached;

    final rows = await _store.getStringList(_attemptsKey) ?? const [];
    final attempts = <String, StoredAttempt>{};
    for (final row in rows) {
      final json = _decode(row);
      if (json == null) continue;
      final attempt = LearningJson.attemptFromJson(json);
      if (attempt == null) continue;
      final stored = StoredAttempt(
        attempt: attempt,
        synced: json['synced'] != false,
      );
      attempts[stored.clientId] = stored;
    }
    return _attempts = attempts;
  }

  Future<List<StoredReview>> _loadReviews() async {
    final cached = _reviews;
    if (cached != null) return cached;

    final rows = await _store.getStringList(_reviewsKey) ?? const [];
    final reviews = <StoredReview>[];
    for (final row in rows) {
      final json = _decode(row);
      if (json == null) continue;
      final review = LearningJson.reviewFromJson(json);
      if (review == null) continue;
      reviews.add(
        StoredReview(review: review, synced: json['synced'] != false),
      );
    }
    reviews.sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
    return _reviews = reviews;
  }

  @override
  Future<LearningRecord> loadRecord() async {
    final attempts =
        (await _loadAttempts()).values.map((stored) => stored.attempt).toList()
          ..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    final reviews = [for (final stored in await _loadReviews()) stored.review];

    return LearningRecord(
      attempts: attempts,
      reviews: reviews,
      // 学習日は回答とレビューの日付から導く。別に持つとズレるため。
      activeDays: {
        for (final attempt in attempts) attempt.answeredAt.dateOnly,
        for (final review in reviews) review.createdAt.dateOnly,
      },
    );
  }

  @override
  Future<void> saveAttempt(StoredAttempt attempt) async {
    final attempts = await _loadAttempts();
    attempts[attempt.clientId] = attempt;
    await _flushAttempts();
  }

  @override
  Future<void> saveReview(StoredReview review) async {
    final reviews = await _loadReviews();
    reviews
      ..removeWhere((existing) => existing.clientId == review.clientId)
      ..insert(0, review);
    await _flushReviews();
  }

  @override
  Future<List<StoredAttempt>> pendingAttempts() async {
    final attempts =
        (await _loadAttempts()).values
            .where((stored) => !stored.synced)
            .toList()
          ..sort(
            (a, b) => a.attempt.answeredAt.compareTo(b.attempt.answeredAt),
          );
    return attempts;
  }

  @override
  Future<List<StoredReview>> pendingReviews() async {
    final reviews =
        (await _loadReviews()).where((stored) => !stored.synced).toList()
          ..sort((a, b) => a.review.createdAt.compareTo(b.review.createdAt));
    return reviews;
  }

  @override
  Future<void> markAttemptsSynced(Iterable<String> clientIds) async {
    final attempts = await _loadAttempts();
    var changed = false;
    for (final clientId in clientIds) {
      final stored = attempts[clientId];
      if (stored == null || stored.synced) continue;
      attempts[clientId] = StoredAttempt(attempt: stored.attempt, synced: true);
      changed = true;
    }
    if (changed) await _flushAttempts();
  }

  @override
  Future<void> markReviewsSynced(Iterable<String> clientIds) async {
    final targets = clientIds.toSet();
    final reviews = await _loadReviews();
    var changed = false;
    for (var i = 0; i < reviews.length; i++) {
      final stored = reviews[i];
      if (stored.synced || !targets.contains(stored.clientId)) continue;
      reviews[i] = StoredReview(review: stored.review, synced: true);
      changed = true;
    }
    if (changed) await _flushReviews();
  }

  @override
  Future<void> mergeRemote({
    required List<QuizAttempt> attempts,
    required List<HandReviewRecord> reviews,
  }) async {
    final localAttempts = await _loadAttempts();
    for (final attempt in attempts) {
      final stored = StoredAttempt(attempt: attempt, synced: true);
      // 未送信のローカル分は上書きしない（送信前に消えてしまうため）。
      if (localAttempts[stored.clientId]?.synced == false) continue;
      localAttempts[stored.clientId] = stored;
    }

    final localReviews = await _loadReviews();
    final known = {
      for (final stored in localReviews)
        if (!stored.synced) stored.clientId,
    };
    localReviews.removeWhere(
      (stored) => stored.synced && !known.contains(stored.clientId),
    );
    for (final review in reviews) {
      if (known.contains(review.id)) continue;
      localReviews.add(StoredReview(review: review, synced: true));
    }
    localReviews.sort(
      (a, b) => b.review.createdAt.compareTo(a.review.createdAt),
    );

    await _flushAttempts();
    await _flushReviews();
  }

  @override
  Future<String?> ownerId() => _store.getString(_ownerKey);

  @override
  Future<void> setOwnerId(String userId) => _store.setString(_ownerKey, userId);

  @override
  Future<void> clear() async {
    _attempts = {};
    _reviews = [];
    await _store.remove(_attemptsKey);
    await _store.remove(_reviewsKey);
  }

  Future<void> _flushAttempts() async {
    final attempts = await _loadAttempts();
    final sorted = attempts.values.toList()
      ..sort((a, b) => a.attempt.answeredAt.compareTo(b.attempt.answeredAt));
    final kept = _trim(sorted, maxAttempts, (stored) => stored.synced);
    if (kept.length != attempts.length) {
      attempts
        ..clear()
        ..addEntries(kept.map((stored) => MapEntry(stored.clientId, stored)));
    }

    await _store.setStringList(_attemptsKey, [
      for (final stored in kept)
        jsonEncode({
          ...LearningJson.attemptToJson(stored.attempt),
          'synced': stored.synced,
        }),
    ]);
  }

  Future<void> _flushReviews() async {
    final reviews = await _loadReviews();
    final kept = _trim(
      reviews.reversed.toList(),
      maxReviews,
      (stored) => stored.synced,
    ).reversed.toList();
    if (kept.length != reviews.length) {
      reviews
        ..clear()
        ..addAll(kept);
    }

    await _store.setStringList(_reviewsKey, [
      for (final stored in kept)
        jsonEncode({
          ...LearningJson.reviewToJson(stored.review),
          'synced': stored.synced,
        }),
    ]);
  }

  /// 古い順に並んだ [items] を [limit] 件に切り詰める。
  /// [isDroppable] が false のもの（未送信）は件数に関わらず残す。
  static List<T> _trim<T>(
    List<T> items,
    int limit,
    bool Function(T item) isDroppable,
  ) {
    if (items.length <= limit) return items;

    var toDrop = items.length - limit;
    final kept = <T>[];
    for (final item in items) {
      if (toDrop > 0 && isDroppable(item)) {
        toDrop--;
        continue;
      }
      kept.add(item);
    }
    return kept;
  }

  static Map<String, dynamic>? _decode(String row) {
    try {
      final json = jsonDecode(row);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }
}
