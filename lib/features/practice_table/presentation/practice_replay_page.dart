import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../application/practice_providers.dart';
import '../domain/grading/decision_grade.dart';
import '../domain/grading/hand_reviewer.dart';
import '../domain/practice_event.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_state.dart';
import 'widgets/practice_explanation_view.dart';

/// 保存済みの 1 ハンドを、イベントを 1 つずつ進めながら振り返る画面。
///
/// 上に「あなたの判断」の○△×の一覧を出し、押すとその判断の場面へ飛ぶ。
/// 再生中にヒーローの行動の場面に来たら、初心者モードと同じ判定と理由を
/// その場で出す（テキストで並べるのではなく、プレイバックしながら振り返る）。
///
/// ライブプレイと同じ [PracticeHandState.replay] を使うので、
/// 表示のロジックが二重にならず、食い違う心配がない。
class PracticeReplayPage extends ConsumerStatefulWidget {
  const PracticeReplayPage({super.key, required this.record});

  final PracticeHandRecord record;

  @override
  ConsumerState<PracticeReplayPage> createState() => _PracticeReplayPageState();
}

class _PracticeReplayPageState extends ConsumerState<PracticeReplayPage> {
  /// いま何個目までのイベントを反映しているか（最低 1 = HandDealt のみ）。
  int _cursor = 1;

  @override
  Widget build(BuildContext context) {
    final events = widget.record.events;
    final visible = events.sublist(0, _cursor);
    final hand = PracticeHandState.replay(visible);
    final lastEvent = events[_cursor - 1];
    final review = ref.watch(practiceHandReviewProvider(widget.record));
    final decisionHere = review.value?.atEvent(_cursor - 1);

    return Scaffold(
      appBar: AppBar(title: const Text('ふりかえり')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    review.when(
                      loading: () => const _GradingRow(),
                      error: (error, _) => const Text(
                        'このハンドは採点できませんでした',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      data: (value) => _ReviewSummary(
                        review: value,
                        currentEventIndex: _cursor - 1,
                        onJump: (decision) =>
                            setState(() => _cursor = decision.eventIndex + 1),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PokerTableView(
                      tableType: hand.tableType,
                      heroPosition: hand.heroPosition,
                      villainPosition: hand.villainPosition,
                      potLabel: 'Pot ${formatBb(hand.pot)}BB',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CardRow(
                      cards: [
                        for (final card in hand.villainCards)
                          PlayingCardView(
                            card: hand.sawShowdown ? card : null,
                            width: 36,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CardRow(
                      cards: [
                        for (final card in hand.board)
                          PlayingCardView(card: card, width: 36),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CardRow(
                      cards: [
                        for (final card in hand.heroCards)
                          PlayingCardView(card: card, width: 36),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _describe(lastEvent),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (decisionHere != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      PracticeExplanationView(
                        explanation: decisionHere.explanation,
                        chosenLabel: decisionHere.chosen.option.label,
                        heroCards: hand.heroCards,
                        board: hand.board,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: '戻る',
                    onPressed: _cursor > 1
                        ? () => setState(() => _cursor--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('$_cursor / ${events.length}'),
                  IconButton(
                    tooltip: '進む',
                    onPressed: _cursor < events.length
                        ? () => setState(() => _cursor++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(PracticeEvent event) {
    return switch (event) {
      HandDealt() => 'ハンド開始',
      BoardDealt(:final street) => '${street.label}が開いた',
      ActionOccurred(:final actor, :final action, :final sizeBb) =>
        '${actor == Actor.hero ? 'あなた' : '相手'} ${action.description}'
            '${sizeBb == null ? '' : ' ${formatBb(sizeBb)}BB'}',
      HandFinished(:final endedByFold, :final winner) =>
        endedByFold
            ? '${winner == Actor.hero ? '相手' : 'あなた'}がフォールド'
            : (winner == null
                  ? 'ショーダウン: 分け'
                  : 'ショーダウン: ${winner == Actor.hero ? 'あなた' : '相手'}の勝ち'),
    };
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(alignment: WrapAlignment.center, spacing: 4, children: cards);
  }
}

class _GradingRow extends StatelessWidget {
  const _GradingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppSpacing.sm),
        Text('採点中…', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// 「あなたの判断」: ○△× の数と、判断ごとのチップ（押すとその場面へ）。
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.review,
    required this.currentEventIndex,
    required this.onJump,
  });

  final PracticeHandReview review;
  final int currentEventIndex;
  final ValueChanged<ReviewedDecision> onJump;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'あなたの判断',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              for (final verdict in PracticeVerdict.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    '${verdict.symbol}${review.countOf(verdict)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: practiceVerdictColor(verdict),
                    ),
                  ),
                ),
            ],
          ),
          if (review.decisions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '押すと、その判断の場面に移動します',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final decision in review.decisions)
                  _DecisionChip(
                    decision: decision,
                    selected: decision.eventIndex == currentEventIndex,
                    onTap: () => onJump(decision),
                  ),
              ],
            ),
          ],
          if (review.ungradedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '採点できなかった判断: ${review.ungradedCount}件'
                '（以前の打ち方の AI と対戦した記録など）',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({
    required this.decision,
    required this.selected,
    required this.onTap,
  });

  final ReviewedDecision decision;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verdict = decision.chosen.verdict;
    final color = practiceVerdictColor(verdict);
    return ActionChip(
      onPressed: onTap,
      backgroundColor: selected
          ? color.withValues(alpha: 0.18)
          : AppColors.surface,
      side: BorderSide(color: color.withValues(alpha: selected ? 0.8 : 0.4)),
      label: Text(
        '${verdict.symbol} ${decision.street.label} '
        '${decision.chosen.option.label}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
