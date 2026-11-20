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
import 'widgets/practice_hand_summary.dart';

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

  /// 採点が終わったら、最初の判断の場面から見せる（一度だけ）。
  bool _movedToFirstDecision = false;

  @override
  Widget build(BuildContext context) {
    final events = widget.record.events;
    final review = ref.watch(practiceHandReviewProvider(widget.record));
    final decisions = review.value?.decisions ?? const <ReviewedDecision>[];
    if (!_movedToFirstDecision && review.hasValue) {
      _movedToFirstDecision = true;
      if (decisions.isNotEmpty) _cursor = decisions.first.eventIndex + 1;
    }
    final visible = events.sublist(0, _cursor);
    final hand = PracticeHandState.replay(visible);
    final lastEvent = events[_cursor - 1];
    final decisionHere = review.value?.atEvent(_cursor - 1);
    ReviewedDecision? previousDecision;
    ReviewedDecision? nextDecision;
    for (final decision in decisions) {
      if (decision.eventIndex < _cursor - 1) previousDecision = decision;
      if (decision.eventIndex > _cursor - 1 && nextDecision == null) {
        nextDecision = decision;
      }
    }

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
                      data: (value) => Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: PracticeHandSummaryBody(
                          review: value,
                          currentEventIndex: _cursor - 1,
                          onTapDecision: (decision) =>
                              setState(() => _cursor = decision.eventIndex + 1),
                        ),
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
                        reasonGrade: decisionHere.reasonGrade,
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
                  TextButton(
                    onPressed: previousDecision == null
                        ? null
                        : () => setState(
                            () => _cursor = previousDecision!.eventIndex + 1,
                          ),
                    child: const Text('前の判断'),
                  ),
                  Text('$_cursor / ${events.length}'),
                  TextButton(
                    onPressed: nextDecision == null
                        ? null
                        : () => setState(
                            () => _cursor = nextDecision!.eventIndex + 1,
                          ),
                    child: const Text('次の判断'),
                  ),
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
