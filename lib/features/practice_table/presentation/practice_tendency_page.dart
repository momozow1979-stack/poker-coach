import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/practice_providers.dart';
import '../domain/practice_opponent.dart';
import '../domain/tendency/practice_tendency.dart';

/// 「AI相手に練習」の記録から見た、あなたの打ち方の傾向。
///
/// 回数（たくさん降りる・たくさん賭ける）ではなく、採点で × になった判断が
/// どの種類に多いかで傾向を見る。相手の打ち方によっては、たくさん降りるのが
/// 正解のこともあるため。
class PracticeTendencyPage extends ConsumerWidget {
  const PracticeTendencyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tendency = ref.watch(practiceTendencyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('あなたの打ち方の傾向')),
      body: SafeArea(
        child: tendency.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('傾向を読み込めませんでした')),
          data: (value) => _Body(tendency: value),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tendency});

  final PracticeTendency tendency;

  @override
  Widget build(BuildContext context) {
    if (tendency.handCount == 0) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'まだ記録がありません。「AI相手に練習」でハンドを最後まで遊ぶと、'
          '判断ごとの採点がたまり、ここに傾向が出ます。',
          style: TextStyle(height: 1.7),
        ),
      );
    }
    final leaks = tendency.leaks;
    final style = tendency.recommendedStyle;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '直近 ${tendency.handCount} ハンド（最大 ${PracticeTendency.recentHands}）の'
          '採点から集計しています。',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '多いミス',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (leaks.isEmpty)
                const Text(
                  '目立つミスの偏りはまだありません'
                  '（同じ種類で × が 2 回以上・2 割以上になると、ここに出ます）。',
                  style: TextStyle(fontSize: 13, height: 1.6),
                )
              else
                for (final leak in leaks) ...[
                  Text(
                    '${leak.label}（× ${tendency.byKind[leak.kind]!.bad} 回）',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leak.advice,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '判断の種類ごとの結果',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final kind in DecisionKind.values)
                _KindRow(kind: kind, stats: tendency.byKind[kind]!),
            ],
          ),
        ),
        if (tendency.reasonStats.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '選んだ理由の正しさ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final entry in tendency.reasonStats.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${entry.value.$1} / ${entry.value.$2}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.accent.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '育つ相手',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                style == PracticeOpponentStyle.standard
                    ? 'いまは突く傾向が無いので「${style.label}」の相手です。'
                    : 'いまのあなたには「${style.label}」の相手が出ます'
                          '（「${tendency.targetedLeak!.label}」を突くため）。',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                style.description,
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '練習画面の「育つ相手」をオンにすると使えます。ミスが減ると、'
                '次に多いミスを突く相手に変わっていきます。',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.stats});

  final DecisionKind kind;
  final KindStats stats;

  @override
  Widget build(BuildContext context) {
    final good = stats.total - stats.bad - stats.close;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kind.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                stats.total == 0
                    ? 'まだ無し'
                    : '○$good　△${stats.close}　×${stats.bad}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (stats.total > 0) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (good > 0)
                      Expanded(
                        flex: good,
                        child: Container(color: AppColors.success),
                      ),
                    if (stats.close > 0)
                      Expanded(
                        flex: stats.close,
                        child: Container(color: AppColors.warning),
                      ),
                    if (stats.bad > 0)
                      Expanded(
                        flex: stats.bad,
                        child: Container(color: AppColors.danger),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
