import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../profile/application/learning_providers.dart';
import '../../range_chart/application/range_providers.dart';
import '../application/quiz_providers.dart';
import '../domain/daily_quiz_session.dart';
import '../domain/quiz_attempt.dart';
import '../domain/quiz_category.dart';
import 'widgets/quiz_session_view.dart';

/// カテゴリを絞った復習クイズ。
///
/// ホームの「苦手分野 / 学びたい分野」タグや、レビュー結果の
/// 「関連クイズ」から遷移する。出題・解説の見た目は「今日の10問」と
/// 共通の [QuizSessionView] を使い、進行状態だけをこのページで持つ。
class CategoryQuizPage extends ConsumerStatefulWidget {
  const CategoryQuizPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryQuizPage> createState() => _CategoryQuizPageState();
}

class _CategoryQuizPageState extends ConsumerState<CategoryQuizPage> {
  DailyQuizSession? _session;
  QuizCategory? _category;

  @override
  void initState() {
    super.initState();
    QuizCategory? category;
    for (final candidate in QuizCategory.values) {
      if (candidate.id == widget.categoryId) {
        category = candidate;
        break;
      }
    }
    _category = category;
    if (category != null) {
      final quizzes = ref.read(quizzesByCategoryProvider(category));
      _session = DailyQuizSession(date: DateTime.now(), quizzes: quizzes);
    }
  }

  void _answer(String choiceId) {
    final session = _session;
    final quiz = session?.currentQuiz;
    if (session == null || quiz == null || session.isAnswerRevealed) return;

    final attempt = QuizAttempt(
      quizId: quiz.id,
      category: quiz.category,
      selectedChoiceId: choiceId,
      isCorrect: quiz.isCorrect(choiceId),
      answeredAt: DateTime.now(),
    );
    ref.read(learningStoreProvider.notifier).recordAttempt(attempt);
    setState(() {
      _session = session.copyWith(
        attempts: {...session.attempts, quiz.id: attempt},
        revealedChoiceId: choiceId,
      );
    });
  }

  void _next() {
    final session = _session;
    if (session == null || !session.isAnswerRevealed) return;
    setState(() {
      _session = session.copyWith(
        currentIndex: session.currentIndex + 1,
        clearRevealedChoice: true,
      );
    });
  }

  void _openRange(String spotId) {
    final chart = ref.read(rangeChartByIdProvider(spotId));
    if (chart == null) return;
    ref.read(selectedTableTypeProvider.notifier).select(chart.spot.tableType);
    ref.read(selectedPositionProvider.notifier).select(chart.spot.heroPosition);
    context.go(AppRoutes.range);
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final session = _session;

    if (category == null || session == null || session.quizzes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('カテゴリ別クイズ')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.quiz_outlined,
            title: 'この分野の問題が見つかりませんでした',
            message: 'ホームに戻ってやり直してください。',
            action: OutlinedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('ホームへ戻る'),
            ),
          ),
        ),
      );
    }

    final quiz = session.currentQuiz;

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.label}を復習'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: session.progress,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${session.currentIndex.clamp(0, session.totalCount - 1) + 1} / ${session.totalCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: quiz == null
            ? _CategoryQuizDone(
                category: category,
                session: session,
                onGoHome: () => context.go(AppRoutes.home),
              )
            : QuizSessionView(
                quiz: quiz,
                selectedChoiceId: session.revealedChoiceId,
                onAnswer: _answer,
                onNext: _next,
                onOpenRange: _openRange,
              ),
      ),
    );
  }
}

class _CategoryQuizDone extends StatelessWidget {
  const _CategoryQuizDone({
    required this.category,
    required this.session,
    required this.onGoHome,
  });

  final QuizCategory category;
  final DailyQuizSession session;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final accuracy = (session.accuracy * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${category.label}の復習が終わりました',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: '正解数',
                      value: '${session.correctCount}',
                      unit: '/ ${session.totalCount}',
                      icon: Icons.check_rounded,
                      valueColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: '正答率',
                      value: '$accuracy',
                      unit: '%',
                      icon: Icons.percent_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onGoHome, child: const Text('ホームに戻る')),
      ],
    );
  }
}
