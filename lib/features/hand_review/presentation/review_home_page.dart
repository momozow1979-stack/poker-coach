import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/section_header.dart';
import '../../profile/application/learning_providers.dart';
import '../domain/hand_review_record.dart';

/// レビュータブの入り口。
///
/// 「意思決定トレーナー」（汎用の練習コンテンツ）は学習タブへ移動したため、
/// このタブは「自分が実際に打ったハンドをレビューする」ことに専念する。
/// 過去のレビュー履歴の一覧と、新しくレビューするための大きなCTAだけを置く。
class ReviewHomePage extends ConsumerWidget {
  const ReviewHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(handReviewHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ハンドレビュー')),
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
            FadeSlideIn(
              child: _ReviewCta(
                historyCount: history.length,
                onTap: () => context.go(AppRoutes.reviewInput),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'レビュー履歴',
              subtitle: history.isEmpty ? null : '${history.length}件',
            ),
            const SizedBox(height: AppSpacing.md),
            if (history.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: 'まだレビューがありません',
                  message: '気になったハンドを1つ入力すると、AIが振り返りを作ります。',
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.reviewInput),
                    child: const Text('ハンドをレビューする'),
                  ),
                ),
              )
            else
              for (var i = 0; i < history.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 40 * i),
                    child: _HistoryCard(
                      record: history[i],
                      onTap: () => context.go(
                        AppRoutes.reviewHistoryDetail(history[i].id),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCta extends StatelessWidget {
  const _ReviewCta({required this.historyCount, required this.onTap});

  final int historyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: AppColors.info.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  size: 24,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'ハンドをレビューする',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              if (historyCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '履歴 $historyCount件',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '実際に自分が打ったハンドを入力すると、AI コーチが振り返りを作ります。'
            '「あのハンド、あれで良かったのかな」を確かめたいときに。',
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.check_rounded, size: 14, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'ポジションは席をタップして選べる',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(historyCount > 0 ? '新しくレビューする' : '入力を始める'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.onTap});

  final HandReviewRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = record.createdAt;
    final dateLabel = '${date.month}/${date.day}';

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              '${record.score}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  record.result.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
