import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/hand_review/presentation/hand_review_page.dart';
import '../features/hand_review/presentation/hand_review_result_page.dart';
import '../features/hand_review/presentation/review_home_page.dart';
import '../features/hand_trainer/presentation/trainer_list_page.dart';
import '../features/hand_trainer/presentation/trainer_play_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/quiz/presentation/quiz_page.dart';
import '../features/range_chart/presentation/range_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'app_shell.dart';

/// 画面のパス定義。
abstract final class AppRoutes {
  static const home = '/home';
  static const quiz = '/quiz';
  static const range = '/range';

  /// レビュータブの入り口。トレーニングと自分のハンド入力を選ぶ。
  static const review = '/review';

  /// 意思決定トレーナーのシナリオ一覧。
  static const trainer = '/review/trainer';

  /// 自分のハンドを入力してレビューする画面。
  static const reviewInput = '/review/input';
  static const reviewResult = '/review/input/result';

  /// 意思決定トレーナーのプレイ画面。
  static String trainerPlay(String scenarioId) => '/review/trainer/$scenarioId';
  static const profile = '/profile';
  static const settings = '/settings';

  /// 下部タブの並び。
  static const tabs = [home, quiz, range, review, profile];
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
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
