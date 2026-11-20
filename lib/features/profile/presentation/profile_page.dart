import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/trend_chart.dart';
import '../../auth/presentation/account_card.dart';
import '../application/learning_providers.dart';
import '../application/progress_providers.dart';
import '../infrastructure/learning_sync_service.dart';
import 'widgets/category_accuracy_list.dart';

/// マイページ / 学習履歴。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final rank = ref.watch(growthRankProvider);
    final stats = ref.watch(learningStatsProvider);
    final reviews = ref.watch(handReviewHistoryProvider);
    final sync = ref.watch(learningSyncControllerProvider);
    final syncing = sync.phase == SyncPhase.syncing;
    // まだ何も表示できる記録が無いのに同期中 = サーバーから読み込んでいる最中。
    // ここで 0 を出すと「データが消えた」と見えるので、数字の代わりに「…」にする。
    final waitingForServer =
        syncing && stats.totalAnswered == 0 && reviews.isEmpty;
    String shown(Object value) => waitingForServer ? '…' : '$value';
    final weak = stats.weakCategories();
    final strong = stats.strongCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => context.go('/profile/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardGlow(),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.rewardGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.cardGlow(
                        color: AppColors.rewardDark,
                      ),
                    ),
                    child: Text(
                      'Lv.${rank.level}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3A1E00),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rank.emoji} ${rank.label} ・ 学習${profile.daysSinceJoined + 1}日目',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ニックネームを変更',
                    onPressed: () =>
                        _editNickname(context, ref, profile.displayName),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
            ),
            if (syncing) ...[
              const SizedBox(height: AppSpacing.lg),
              _SyncProgress(waitingForServer: waitingForServer),
            ],
            if (!syncing && stats.totalAnswered == 0 && reviews.isEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'まだ学習データがありません',
                  message: '今日の10問を解くと、連続日数・正答率・苦手分野がここに記録されます。',
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.quiz),
                    child: const Text('今日の10問を始める'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: '連続学習',
                    value: shown(stats.streakDays),
                    unit: '日',
                    icon: Icons.local_fire_department_rounded,
                    valueColor: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: '解いた問題',
                    value: shown(stats.totalAnswered),
                    unit: '問',
                    icon: Icons.quiz_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: '総合正答率',
                    value: shown((stats.accuracy * 100).round()),
                    unit: '%',
                    icon: Icons.percent_rounded,
                    valueColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: 'レビュー',
                    value: shown(reviews.length),
                    unit: '件',
                    icon: Icons.rate_review_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: '直近7日の学習日',
                    value: shown(stats.activeDaysLast7),
                    unit: '日',
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: '直近30日の学習日',
                    value: shown(stats.activeDaysLast30),
                    unit: '日',
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'アカウントと保存状況',
              subtitle: '履歴がどこに保存されているか',
            ),
            const SizedBox(height: AppSpacing.md),
            const AccountCard(),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: '得意 / 苦手', subtitle: '各カテゴリ3問以上で判定します'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '得意分野',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (strong.isEmpty)
                    const Text(
                      'まだ判定できていません。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final category in strong)
                          TagChip(
                            label: category.label,
                            color: AppColors.success,
                            icon: Icons.check_rounded,
                          ),
                      ],
                    ),
                  const Divider(height: AppSpacing.xl),
                  const Text(
                    '苦手分野',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (weak.isEmpty)
                    const Text(
                      'まだ判定できていません。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final category in weak)
                          TagChip(
                            label: category.label,
                            color: AppColors.danger,
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: '正答率の推移', subtitle: '直近14日'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: TrendChart(
                points: [
                  for (final day in stats.dailyAccuracy())
                    TrendPoint(
                      label: '${day.day.month}/${day.day.day}',
                      value: day.accuracy,
                    ),
                ],
                height: 110,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'カテゴリ別の正答率', subtitle: '外側に膨らむほど得意'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: stats.categoryStats.isEmpty
                  ? const EmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: 'まだデータがありません',
                      message: '今日の10問を解くとここに表示されます。',
                    )
                  : CategoryAccuracyChart(stats: stats.categoryStats),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNickname(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ニックネーム'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '表示名を入力'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(profileStoreProvider.notifier).setNickname(name);
    }
  }
}

/// 同期中の進行バー。
///
/// 送受信する件数は終わるまで分からないので、何%かは出せない。
/// 「動いている」ことが分かる流れるバーにする。
class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.waitingForServer});

  /// まだ記録が 1 件も表示できていない（＝ログイン直後など）。
  final bool waitingForServer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_sync_rounded,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  waitingForServer
                      ? 'サーバーから学習の記録を読み込んでいます…'
                      : '最新の記録をサーバーと確認しています…',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 6,
              color: AppColors.info,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
          if (waitingForServer) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'ログイン直後や、しばらく使っていなかったあとは時間がかかることがあります。'
              '記録は消えていないので、このままお待ちください。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
