import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../profile/application/learning_providers.dart';

/// レビュータブの入り口。2つのモードから選ぶ。
///
/// 初心者はまずトレーニングから入るのが自然なので、そちらを先に大きく置く。
class ReviewHomePage extends ConsumerWidget {
  const ReviewHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyCount = ref.watch(handReviewHistoryProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('ハンドで練習する')),
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
            const Text(
              'やりたいことを選んでください。',
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              child: _ModeCard(
                icon: Icons.sports_esports_rounded,
                accent: AppColors.accent,
                onAccent: AppColors.onAccent,
                badge: 'おすすめ',
                title: '意思決定トレーナー',
                description:
                    '用意されたハンドを、プリフロップからリバーまで'
                    '1ストリートずつ自分で選んで進みます。'
                    '選んだ直後に「なぜそうなるか」が出るので、'
                    '実戦の経験がなくても練習できます。',
                bullets: const [
                  '図でボードとポットが見える',
                  '分からない言葉はその場で確認できる',
                  '間違えても、何が変われば答えが変わるかまで分かる',
                ],
                actionLabel: 'ハンドを選ぶ',
                onTap: () => context.go(AppRoutes.trainer),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _ModeCard(
                icon: Icons.rate_review_rounded,
                accent: AppColors.info,
                onAccent: Colors.white,
                badge: historyCount > 0 ? '履歴 $historyCount件' : null,
                title: '自分のハンドをレビュー',
                description:
                    '実際に自分が打ったハンドを入力して、'
                    'AI コーチのコメントをもらいます。'
                    '「あのハンド、あれで良かったのかな」を確かめたいときに。',
                bullets: const ['ポジションは席をタップして選べる', '入力はほぼタップだけで終わる'],
                actionLabel: '入力を始める',
                onTap: () => context.go(AppRoutes.reviewInput),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.accent,
    required this.onAccent,
    required this.title,
    required this.description,
    required this.bullets,
    required this.actionLabel,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color accent;

  /// [accent] を背景にしたときに読める文字色。
  final Color onAccent;

  final String title;
  final String description;
  final List<String> bullets;
  final String actionLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                ),
                child: Icon(icon, size: 24, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 3,
                      right: AppSpacing.sm,
                    ),
                    child: Icon(Icons.check_rounded, size: 14, color: accent),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: onAccent,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
