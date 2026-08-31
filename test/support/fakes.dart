import 'dart:async';

import 'package:ai_poker_coach/features/auth/domain/app_user.dart';
import 'package:ai_poker_coach/features/auth/domain/auth_gateway.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_input.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_record.dart';
import 'package:ai_poker_coach/features/hand_review/domain/hand_review_result.dart';
import 'package:ai_poker_coach/features/profile/domain/learning_stores.dart';
import 'package:ai_poker_coach/features/profile/domain/user_profile.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_attempt.dart';
import 'package:ai_poker_coach/features/quiz/domain/quiz_category.dart';
import 'package:ai_poker_coach/shared/models/playing_card.dart';
import 'package:ai_poker_coach/shared/models/poker_action.dart';

/// このコンテナからは Supabase に到達できないため、テストは実通信しない。
/// Supabase 側の振る舞い（成功・失敗・別ユーザー）はこのフェイクで再現する。
class FakeRemoteLearningStore implements RemoteLearningStore {
  FakeRemoteLearningStore({this.enabled = true});

  bool enabled;

  /// true の間、すべての通信が失敗する（圏外の再現）。
  bool offline = false;

  final Map<String, StoredAttempt> attempts = {};
  final Map<String, StoredReview> reviews = {};
  final Map<String, (int, int)> categoryStats = {};
  final Map<String, UserProfile> profiles = {};

  int fetchCount = 0;
  int pushAttemptCount = 0;

  @override
  bool get isEnabled => enabled;

  void _guard() {
    if (offline) throw const SocketFailure();
  }

  @override
  Future<RemoteSnapshot> fetchAll(String userId) async {
    _guard();
    fetchCount++;
    return RemoteSnapshot(
      attempts: attemptsOf(userId),
      reviews: reviewsOf(userId),
    );
  }

  @override
  Future<void> pushAttempts(String userId, List<StoredAttempt> batch) async {
    _guard();
    pushAttemptCount += batch.length;
    for (final stored in batch) {
      // (user_id, client_id) の一意制約と同じ効果。再送しても増えない。
      attempts['$userId::${stored.clientId}'] = StoredAttempt(
        attempt: stored.attempt,
        synced: true,
      );
    }
  }

  @override
  Future<void> pushReviews(String userId, List<StoredReview> batch) async {
    _guard();
    for (final stored in batch) {
      reviews['$userId::${stored.clientId}'] = StoredReview(
        review: stored.review,
        synced: true,
      );
    }
  }

  @override
  Future<void> pushCategoryStats(
    String userId,
    Map<String, (int, int)> stats,
  ) async {
    _guard();
    categoryStats
      ..clear()
      ..addAll(stats);
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    _guard();
    return profiles[userId];
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    _guard();
    profiles[profile.id] = profile;
  }
}

/// fetchAll のフィルタと突き合わせるためのキー付け。
extension FakeRemoteKeys on FakeRemoteLearningStore {
  List<QuizAttempt> attemptsOf(String userId) => [
    for (final entry in attempts.entries)
      if (entry.key.startsWith('$userId::')) entry.value.attempt,
  ];

  List<HandReviewRecord> reviewsOf(String userId) => [
    for (final entry in reviews.entries)
      if (entry.key.startsWith('$userId::')) entry.value.review,
  ];
}

class SocketFailure implements Exception {
  const SocketFailure();

  @override
  String toString() => '通信できません';
}

/// 匿名サインインと昇格を再現する認証フェイク。
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.anonymousSignInEnabled = true});

  /// false のとき、Supabase 側で Anonymous sign-ins が無効な状態を再現する。
  bool anonymousSignInEnabled;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  AuthFailure? _failure;
  int _counter = 0;

  @override
  Stream<AppUser?> get changes => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  AuthFailure? get lastFailure => _failure;

  @override
  Future<AppUser?> ensureSignedIn() async {
    if (_user != null) return _user;
    if (!anonymousSignInEnabled) {
      _failure = const AuthFailure(
        'Anonymous sign-ins が無効です。',
        isAnonymousSignInDisabled: true,
      );
      return null;
    }
    _failure = null;
    return _emit(AppUser(id: 'anon-${++_counter}', isAnonymous: true));
  }

  @override
  Future<AppUser> registerEmail({
    required String email,
    required String password,
  }) async {
    final current = await ensureSignedIn();
    if (current == null) throw _failure!;
    // 昇格しても user_id は変わらない。
    return _emit(AppUser(id: current.id, isAnonymous: false, email: email));
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async =>
      _emit(AppUser(id: 'user-of-$email', isAnonymous: false, email: email));

  @override
  Future<void> signOut() async {
    _user = null;
    await ensureSignedIn();
  }

  AppUser _emit(AppUser user) {
    _user = user;
    _controller.add(user);
    return user;
  }

  void dispose() => _controller.close();
}

/// テスト用のデータ生成 ---------------------------------------------------

QuizAttempt fakeAttempt({
  required String quizId,
  required DateTime answeredAt,
  bool isCorrect = true,
  QuizCategory category = QuizCategory.preflop,
}) => QuizAttempt(
  quizId: quizId,
  category: category,
  selectedChoiceId: isCorrect ? 'a' : 'b',
  isCorrect: isCorrect,
  answeredAt: answeredAt,
);

HandReviewRecord fakeReview({
  required String id,
  required DateTime createdAt,
  int score = 72,
}) => HandReviewRecord(
  id: id,
  createdAt: createdAt,
  input: HandReviewInput(
    heroHand: PlayingCard.parseAll(const ['Ah', 'Kd']),
    preflop: const [
      HandAction(actor: HandAction.heroActor, action: PokerActionType.raise),
    ],
  ),
  result: HandReviewResult(
    score: score,
    summary: 'テスト用のレビュー',
    goodPoints: const ['ポジションを活かせている'],
    mainImprovement: 'ターンのサイズ',
    streetAnalysis: const {'preflop': 'OK'},
    gtoView: 'GTO',
    practicalAdjustment: '実戦',
    alternativeLines: const ['チェック'],
    nextFocus: 'ターン',
    relatedQuizTopics: const ['turn'],
  ),
);
