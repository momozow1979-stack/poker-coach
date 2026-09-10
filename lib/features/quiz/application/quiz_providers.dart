import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_x.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../profile/application/learning_providers.dart';
import '../domain/daily_quiz_session.dart';
import '../domain/quiz.dart';
import '../domain/quiz_attempt.dart';
import '../domain/quiz_category.dart';
import '../domain/quiz_repository.dart';
import '../infrastructure/mock_quiz_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => const MockQuizRepository(),
);

/// 「今日の10問」。
///
/// 苦手カテゴリを一定数まで優先しつつ、直近に出した問題は除外する。
class DailyQuizController extends Notifier<DailyQuizSession> {
  /// このセッション中に「新しい10問」で一度でも出した問題の ID。
  /// 同じ日にもう一度「新しい10問」を選んでも、これらは出さない。
  Set<String> _seenIds = {};

  @override
  DailyQuizSession build() {
    final today = DateTime.now().dateOnly;
    final quizzes = _pickQuizzes(today, excludeIds: const {});
    _seenIds = {for (final quiz in quizzes) quiz.id};
    return DailyQuizSession(date: today, quizzes: quizzes);
  }

  /// build 時に read で固定する。回答して履歴が増えても出題は組み直さない。
  List<Quiz> _pickQuizzes(DateTime date, {required Set<String> excludeIds}) {
    final stats = ref.read(learningStatsProvider);
    final weakCategories = stats.weakCategories();
    // 苦手分野がまだ検出できていない間は、オンボーディングで選んだ
    // 「学びたい分野」を代わりに優先出題する。
    final onboardingFocus =
        ref.read(onboardingAnswersProvider)?.focusCategories ?? const [];
    final priorityCategories = weakCategories.isNotEmpty
        ? weakCategories
        : onboardingFocus;
    return ref
        .read(quizRepositoryProvider)
        .dailyQuizzes(
          date,
          weakCategories: priorityCategories,
          lastAnsweredAt: stats.lastAnsweredAt,
          excludeIds: excludeIds,
        );
  }

  /// 選択肢を選んで答え合わせを表示する。
  void answer(String choiceId) {
    final quiz = state.currentQuiz;
    if (quiz == null || state.isAnswerRevealed) return;

    final attempt = QuizAttempt(
      quizId: quiz.id,
      category: quiz.category,
      selectedChoiceId: choiceId,
      isCorrect: quiz.isCorrect(choiceId),
      answeredAt: DateTime.now(),
    );

    ref.read(learningStoreProvider.notifier).recordAttempt(attempt);
    state = state.copyWith(
      attempts: {...state.attempts, quiz.id: attempt},
      revealedChoiceId: choiceId,
    );
  }

  /// 次の問題へ進む。
  void next() {
    if (!state.isAnswerRevealed) return;
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      clearRevealedChoice: true,
    );
  }

  /// 同じ 10 問を最初からやり直す。
  void restart() {
    state = DailyQuizSession(date: state.date, quizzes: state.quizzes);
  }

  /// 今日まだ出していない、新しい10問に挑戦する。
  ///
  /// 出題プールが尽きて重複を避けきれない場合は、
  /// [QuizRepository.dailyQuizzes] が通常のクールダウンルールに従って
  /// 埋め合わせる（無理に10問を切ってまで重複回避を優先しない）。
  void newSet() {
    final quizzes = _pickQuizzes(state.date, excludeIds: _seenIds);
    _seenIds = {..._seenIds, for (final quiz in quizzes) quiz.id};
    state = DailyQuizSession(date: state.date, quizzes: quizzes);
  }
}

final dailyQuizSessionProvider =
    NotifierProvider<DailyQuizController, DailyQuizSession>(
      DailyQuizController.new,
    );

/// カテゴリを指定した復習問題（クイズ解説・レビュー結果からの導線）。
final quizzesByCategoryProvider = Provider.family<List<Quiz>, QuizCategory>((
  ref,
  category,
) {
  return ref.watch(quizRepositoryProvider).byCategory(category);
});
