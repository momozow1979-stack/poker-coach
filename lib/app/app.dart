import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/profile/application/learning_providers.dart';
import 'router.dart';

/// アプリのルート。
///
/// 端末に保存した学習履歴を読み終わるまでは起動画面を出す。
/// 先に空の状態を描いてから履歴が差し替わると、連続日数などが一瞬 0 に見えるため。
class AiPokerCoachApp extends ConsumerWidget {
  const AiPokerCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(learningBootstrapProvider);

    if (bootstrap.isLoading) {
      return MaterialApp(
        title: 'AI Poker Coach',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _StartupScreen(),
      );
    }

    return const _MainApp();
  }
}

class _MainApp extends ConsumerStatefulWidget {
  const _MainApp();

  @override
  ConsumerState<_MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<_MainApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 圏外で溜まった分を、アプリに戻ってきたタイミングで送り直す。
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(learningSyncControllerProvider.notifier).syncNow(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 認証状態の変化を受け取り続けるために、ここで生かしておく。
    ref.watch(accountProvider);

    return MaterialApp.router(
      title: 'AI Poker Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// 起動直後の画面。ローカル読み込みは一瞬なので、アニメーションは置かない。
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Poker Coach',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '学習履歴を読み込んでいます',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// `--dart-define` の設定が足りないときに出す画面。
///
/// 設定なしで動かすとモックにフォールバックしたのと同じ状態になるため、
/// アプリを起動させずに原因を出す。
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Poker Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.settings_ethernet_rounded,
                  color: AppColors.danger,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  '起動設定が足りません',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final error in errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '・$error',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'ビルド時に次の値を渡してください:\n'
                  '--dart-define=SUPABASE_URL=https://xxxx.supabase.co\n'
                  '--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.8,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
