import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/hand_review/presentation/hand_review_page.dart';
import '../features/hand_review/presentation/hand_review_result_page.dart';
import '../features/hand_review/presentation/review_home_page.dart';
import '../features/hand_trainer/presentation/trainer_list_page.dart';
import '../features/hand_trainer/presentation/trainer_play_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/presentation/onboarding_flow_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/quiz/presentation/category_quiz_page.dart';
import '../features/quiz/presentation/quiz_page.dart';
import '../features/range_chart/presentation/range_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'app_shell.dart';

/// 画面のパス定義。
abstract final class AppRoutes {
  static const home = '/home';
  static const quiz = '/quiz';
  static const range = '/range';

  /// レビュータブの入り口。自分のハンドのレビュー専用。
  static const review = '/review';

  /// ハンドトレーナーのシナリオ一覧（学習タブの下）。
  static const trainer = '/quiz/trainer';

  /// ハンドトレーナーのプレイ画面。
  static String trainerPlay(String scenarioId) => '/quiz/trainer/$scenarioId';

  /// カテゴリを指定した復習クイズ。
  static String categoryQuiz(String categoryId) => '/quiz/category/$categoryId';

  /// 自分のハンドを入力してレビューする画面。
  static const reviewInput = '/review/input';
  static const reviewResult = '/review/input/result';

  /// 過去のレビュー結果を、履歴から開いたときの画面。
  static String reviewHistoryDetail(String recordId) =>
      '/review/history/$recordId';
  static const profile = '/profile';
  static const settings = '/settings';

  /// 初回起動時のオンボーディング。
  static const onboarding = '/onboarding';

  /// 下部タブの並び。
  static const tabs = [home, quiz, range, review, profile];
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      // オンボーディングの完了判定は `onboardingBootstrapProvider` が起動時に
      // 読み込み終えている前提（`AiPokerCoachApp` がそれまで画面を出さない）。
      final completed = ref.read(onboardingAnswersProvider) != null;
      final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!completed && !goingToOnboarding) return AppRoutes.onboarding;
      if (completed && goingToOnboarding) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingFlowPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.quiz,
                builder: (context, state) => const QuizPage(),
                routes: [
                  GoRoute(
                    path: 'trainer',
                    builder: (context, state) => const TrainerListPage(),
                    routes: [
                      GoRoute(
                        path: ':scenarioId',
                        builder: (context, state) => TrainerPlayPage(
                          scenarioId: state.pathParameters['scenarioId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'category/:categoryId',
                    builder: (context, state) => CategoryQuizPage(
                      categoryId: state.pathParameters['categoryId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.range,
                builder: (context, state) => const RangePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.review,
                builder: (context, state) => const ReviewHomePage(),
                routes: [
                  GoRoute(
                    path: 'input',
                    builder: (context, state) => const HandReviewPage(),
                    routes: [
                      GoRoute(
                        path: 'result',
                        builder: (context, state) =>
                            const HandReviewResultPage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'history/:recordId',
                    builder: (context, state) => HandReviewResultPage(
                      recordId: state.pathParameters['recordId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
