import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../profile/application/learning_providers.dart';
import '../../profile/infrastructure/learning_sync_service.dart';
import '../application/auth_providers.dart';
import 'auth_sheet.dart';

/// アカウントと保存状況をまとめたカード。マイページに置く。
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(accountProvider);
    final sync = ref.watch(learningSyncControllerProvider);
    final failure = ref.read(accountProvider.notifier).lastFailure;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                user == null
                    ? Icons.cloud_off_rounded
                    : (user.isRegistered
                          ? Icons.verified_user_rounded
                          : Icons.person_outline_rounded),
                size: 18,
                color: user?.isRegistered == true
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'アカウント',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user?.statusLabel ?? 'サインインしていません',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SyncStatusLine(status: sync),
          // 同期状況の行が既に事情を説明しているときは重ねない。
          // 同じ原因の文言が2つ並ぶと、深刻な問題が起きたように見える。
          if (user == null && failure != null && sync.message == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failure.message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (user?.isRegistered == true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await ref.read(accountProvider.notifier).signOut();
                  await ref
                      .read(learningSyncControllerProvider.notifier)
                      .syncNow();
                },
                child: const Text('ログアウト'),
              ),
            )
          else ...[
            const Text(
              'メールアドレスを登録すると、機種変更や別の端末でも同じ履歴を続けられます。'
              '今の履歴はそのまま引き継がれます。',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        showAuthSheet(context, AuthSheetMode.register),
                    child: const Text('メールで登録'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        showAuthSheet(context, AuthSheetMode.signIn),
                    child: const Text('ログイン'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 「保存できているか」を 1 行で出す。
class _SyncStatusLine extends StatelessWidget {
  const _SyncStatusLine({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.phase) {
      SyncPhase.synced when status.pendingCount == 0 => (
        'Supabase に保存済み',
        AppColors.success,
      ),
      SyncPhase.syncing => ('同期中…', AppColors.info),
      SyncPhase.synced || SyncPhase.failed || SyncPhase.offline => (
        '未同期 ${status.pendingCount} 件（この端末には保存済み）',
        AppColors.warning,
      ),
      SyncPhase.idle => ('この端末に保存中', AppColors.textMuted),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        if (status.message case final message?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: const TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
