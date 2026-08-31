import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/learning_stores.dart';
import '../domain/user_profile.dart';
import 'learning_json.dart';

/// Supabase の `quiz_attempts` / `hand_reviews` / `learning_stats` / `profiles`
/// への読み書き。
///
/// 同期の冪等性は `(user_id, client_id)` の一意制約で担保する。
/// 送信結果が分からないまま再送しても、行が二重にならない。
///
/// クイズ本体はアプリに同梱したままなので、`quizzes` テーブルは参照しない。
/// アプリ内の問題 ID は `quiz_key`（text）へ、`quiz_id`（uuid）は NULL のまま。
class SupabaseLearningStore implements RemoteLearningStore {
  SupabaseLearningStore(this._client);

  final SupabaseClient _client;

  /// 端末に持ち帰る件数の上限。ローカルの保持上限に合わせている。
  static const _attemptLimit = 5000;
  static const _reviewLimit = 300;

  @override
  bool get isEnabled => true;

  @override
  Future<RemoteSnapshot> fetchAll(String userId) async {
    final attemptRows = await _client
        .from('quiz_attempts')
        .select(
          'quiz_key, category, selected_answer_json, is_correct, '
          'answered_at',
        )
        .eq('user_id', userId)
        .order('answered_at', ascending: false)
        .limit(_attemptLimit);

    final reviewRows = await _client
        .from('hand_reviews')
        .select('client_id, input_json, ai_response_json, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(_reviewLimit);

    return RemoteSnapshot(
      attempts: attemptRows
          .map(
            (row) => LearningJson.attemptFromJson({
              'quiz_key': row['quiz_key'],
              'category': row['category'],
              'selected_choice_id':
                  (row['selected_answer_json'] as Map?)?['choice_id'],
              'is_correct': row['is_correct'],
              'answered_at': row['answered_at'],
            }),
          )
          .nonNulls
          .toList(),
      reviews: reviewRows
          .map(
            (row) => LearningJson.reviewFromJson({
              'id': row['client_id'],
              'created_at': row['created_at'],
              'input': row['input_json'],
              'result': row['ai_response_json'],
            }),
          )
          .nonNulls
          .toList(),
    );
  }

  @override
  Future<void> pushAttempts(String userId, List<StoredAttempt> attempts) async {
    if (attempts.isEmpty) return;

    await _client.from('quiz_attempts').upsert([
      for (final stored in attempts)
        {
          'user_id': userId,
          'client_id': stored.clientId,
          'quiz_key': stored.attempt.quizId,
          'category': stored.attempt.category.id,
          'selected_answer_json': {
            'choice_id': stored.attempt.selectedChoiceId,
          },
          'is_correct': stored.attempt.isCorrect,
          'answered_at': stored.attempt.answeredAt.toUtc().toIso8601String(),
        },
    ], onConflict: 'user_id,client_id');
  }

  @override
  Future<void> pushReviews(String userId, List<StoredReview> reviews) async {
    if (reviews.isEmpty) return;

    await _client.from('hand_reviews').upsert([
      for (final stored in reviews)
        {
          'user_id': userId,
          'client_id': stored.clientId,
          'input_json': stored.review.input.toJson(),
          'ai_response_json': stored.review.result.toJson(),
          'score': stored.review.score,
          'created_at': stored.review.createdAt.toUtc().toIso8601String(),
        },
    ], onConflict: 'user_id,client_id');
  }

  @override
  Future<void> pushCategoryStats(
    String userId,
    Map<String, (int, int)> stats,
  ) async {
    if (stats.isEmpty) return;

    await _client.from('learning_stats').upsert([
      for (final entry in stats.entries)
        {
          'user_id': userId,
          'category': entry.key,
          'correct_count': entry.value.$1,
          'incorrect_count': entry.value.$2,
          'last_updated': DateTime.now().toUtc().toIso8601String(),
        },
    ], onConflict: 'user_id,category');
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, display_name, poker_level, created_at')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;

    return UserProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? 'プレイヤー',
      pokerLevel: PokerLevel.values.firstWhere(
        (level) => level.id == row['poker_level'],
        orElse: () => PokerLevel.novice,
      ),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      'display_name': profile.displayName,
      'poker_level': profile.pokerLevel.id,
      'created_at': profile.createdAt.toUtc().toIso8601String(),
    });
  }
}
