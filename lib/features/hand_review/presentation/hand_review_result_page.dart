import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/collapsible_section.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../../shared/widgets/score_ring.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../quiz/domain/quiz_category.dart';
import '../application/hand_review_providers.dart';
import '../domain/hand_review_record.dart';

/// ハンドレビューの結果画面。仕様書 3-5 の表示順に合わせている。
///
/// [recordId] が無ければ、直近に入力画面から提出した結果
/// （[handReviewControllerProvider]）を表示する（従来どおりの動線）。
/// [recordId] があれば、レビュー履歴から指定した過去の1件を表示する
/// （レビュータブの履歴一覧からのドリルダウン）。
class HandReviewResultPage extends ConsumerWidget {
  const HandReviewResultPage({super.key, this.recordId});

  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordId = this.recordId;
    final record = recordId == null
        ? ref.watch(handReviewControllerProvider).value
        : ref.watch(handReviewRecordByIdProvider(recordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('レビュー結果'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(
            recordId == null ? AppRoutes.reviewInput : AppRoutes.review,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: record == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'レビュー結果がありません',
                  message: '入力画面からAIレビューを実行してください。',
                ),
              )
            : _ResultBody(record: record),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.record});

  final HandReviewRecord record;

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    final input = record.input;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  ScoreRing(score: result.score),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'あなたのハンド',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PlayingCardRow(
                          cards: input.heroHand,
                          width: 40,
                          dealAnimation: true,
                        ),
                        if (input.board.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PlayingCardRow(
                            cards: input.board,
                            width: 30,
                            dealAnimation: true,
                            dealDelay: const Duration(milliseconds: 180),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PokerTableView(
                tableType: input.tableType,
                heroPosition: input.heroPosition,
                villainPosition: input.villainPosition,
                potLabel: input.effectiveStackBb == null
                    ? null
                    : '${input.effectiveStackBb!.toInt()}BB',
                height: 132,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                result.summary,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ListSection(
          title: '良かった点',
          icon: Icons.thumb_up_rounded,
          accent: AppColors.success,
          items: result.goodPoints,
        ),
        _TextSection(
          title: '一番直したいポイント',
          icon: Icons.priority_high_rounded,
          accent: AppColors.danger,
          body: result.mainImprovement,
        ),
        const SizedBox(height: AppSpacing.sm),
        const SectionHeader(title: 'くわしく見る', subtitle: '読みたい項目をタップして開いてください'),
        const SizedBox(height: AppSpacing.md),
        for (final entry in _orderedStreets(result.streetAnalysis))
          CollapsibleSection(
            icon: Icons.layers_rounded,
            title: entry.$1,
            body: entry.$2,
            accent: AppColors.info,
          ),
        CollapsibleSection(
          icon: Icons.functions_rounded,
          title: 'GTO視点',
          body: result.gtoView,
          accent: AppColors.info,
        ),
        CollapsibleSection(
          icon: Icons.sports_esports_rounded,
          title: '実戦調整（相手: ${input.villainProfile.label}）',
          body: result.practicalAdjustment,
          accent: AppColors.warning,
        ),
        for (final line in result.alternativeLines)
          CollapsibleSection(
            icon: Icons.alt_route_rounded,
            title: '別のライン',
            body: line,
            accent: AppColors.rangeThreeBet,
          ),
        const SizedBox(height: AppSpacing.sm),
        _TextSection(
          title: '次回の課題',
          icon: Icons.flag_rounded,
          accent: AppColors.accent,
          body: result.nextFocus,
        ),
        if (result.relatedQuizTopics.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const SectionHeader(title: '関連クイズ', subtitle: 'このハンドから見つかったテーマ'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final topic in result.relatedQuizTopics)
                      TagChip(label: _topicLabel(topic)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.quiz),
                    icon: const Icon(Icons.school_rounded, size: 18),
                    label: const Text('関連クイズを解く'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'この結果はアプリ内のローカル解析によるものです。'
          'Supabase Edge Function 接続後は、同じ表示のままAIの出力に切り替わります。',
          style: TextStyle(
            fontSize: 11,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  static List<(String, String)> _orderedStreets(Map<String, String> analysis) {
    const order = {
      'preflop': 'Preflop',
      'flop': 'Flop',
      'turn': 'Turn',
      'river': 'River',
    };
    return [
      for (final entry in order.entries)
        if (analysis[entry.key] case final body? when body.isNotEmpty)
          (entry.value, body),
    ];
  }

  static String _topicLabel(String topicId) {
    for (final category in QuizCategory.values) {
      if (category.id == topicId) return category.label;
    }
    return topicId;
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.body,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 7,
                        right: AppSpacing.sm,
                      ),
                      child: Icon(Icons.circle, size: 5, color: accent),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
