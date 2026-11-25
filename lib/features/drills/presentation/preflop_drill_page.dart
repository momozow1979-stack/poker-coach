import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/position.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../range_chart/domain/range_action.dart';
import '../../range_chart/domain/range_guidance.dart';
import '../application/drill_providers.dart';
import '../domain/preflop_drill.dart';

/// プリフロップ連続ドリル。
///
/// 席・状況・手札がランダムに出て、レンジ表どおりの答えをテンポよく選ぶ。
/// 答えるとすぐ ○× と理由が出る。20 問で 1 セッション。
class PreflopDrillPage extends ConsumerStatefulWidget {
  const PreflopDrillPage({super.key});

  @override
  ConsumerState<PreflopDrillPage> createState() => _PreflopDrillPageState();
}

class _PreflopDrillPageState extends ConsumerState<PreflopDrillPage> {
  late PreflopDrillSession _session;
  Position? _onlyPosition;

  @override
  void initState() {
    super.initState();
    _session = _newSession();
  }

  PreflopDrillSession _newSession({List<PreflopDrillQuestion>? retry}) =>
      PreflopDrillSession(
        ref.read(preflopDrillGeneratorProvider),
        onlyPosition: _onlyPosition,
        retryQuestions: retry,
      );

  void _restart({List<PreflopDrillQuestion>? retry}) =>
      setState(() => _session = _newSession(retry: retry));

  void _setPosition(Position? position) {
    _onlyPosition = position;
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('プリフロップ連続ドリル')),
      body: SafeArea(
        child: session.isFinished
            ? _Summary(
                session: session,
                onRestart: () => _restart(),
                onRetryMistakes: session.mistakes.isEmpty
                    ? null
                    : () => _restart(
                        retry: [for (final m in session.mistakes) m.question],
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _PositionFilter(
                    selected: _onlyPosition,
                    positions: {
                      for (final chart
                          in ref.read(preflopDrillGeneratorProvider).charts)
                        chart.spot.heroPosition,
                    }.toList(),
                    onSelected: _setPosition,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ProgressRow(session: session),
                  const SizedBox(height: AppSpacing.md),
                  _QuestionCard(question: session.current),
                  const SizedBox(height: AppSpacing.md),
                  if (session.lastResult == null)
                    _AnswerButtons(
                      question: session.current,
                      onAnswer: (answer) =>
                          setState(() => session.answer(answer)),
                    )
                  else
                    _ResultPanel(
                      result: session.lastResult!,
                      isLast: session.isLastAnswered,
                      onNext: () => setState(session.next),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PositionFilter extends StatelessWidget {
  const _PositionFilter({
    required this.selected,
    required this.positions,
    required this.onSelected,
  });

  final Position? selected;
  final List<Position> positions;
  final ValueChanged<Position?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      for (final position in Position.values)
        if (positions.contains(position)) position,
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          label: const Text('全部の席'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final position in ordered)
          ChoiceChip(
            label: Text(position.label),
            selected: selected == position,
            onSelected: (_) => onSelected(position),
          ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.session});

  final PreflopDrillSession session;

  @override
  Widget build(BuildContext context) {
    final current = (session.answered + (session.lastResult == null ? 1 : 0))
        .clamp(1, session.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$current / ${session.total} 問',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '正解 ${session.correct}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: session.streak > 0
                  ? AppColors.warning
                  : AppColors.textMuted,
            ),
            Text(
              ' 連続 ${session.streak}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: session.answered / session.total,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final PreflopDrillQuestion question;

  @override
  Widget build(BuildContext context) {
    final spot = question.spot;
    return AppCard(
      child: Column(
        children: [
          Text(
            question.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            question.isOpen
                ? '6MAX・100BB。あなたが最初に参加するか決めます'
                : '6MAX・100BB。相手は 2.5BB にオープン',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PokerTableView(
            tableType: spot.tableType,
            heroPosition: spot.heroPosition,
            villainPosition: spot.villainPosition,
            height: 120,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final card in question.cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PlayingCardView(card: card, width: 56),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.question, required this.onAnswer});

  final PreflopDrillQuestion question;
  final ValueChanged<PreflopDrillAnswer> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final answer in question.choices) ...[
          if (answer != question.choices.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => onAnswer(answer),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              // 3 つ並んでも折り返さないよう、狭ければ縮める。
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  answer.label,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.isLast,
    required this.onNext,
  });

  final PreflopDrillResult result;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final question = result.question;
    final ok = result.isCorrect;
    final color = ok ? AppColors.success : AppColors.danger;
    final guidance = RangeGuidanceBuilder.build(
      spot: question.spot,
      entry: question.entry,
    );
    final answers = question.correctAnswers;
    final isBoundary = question.entry.action == RangeAction.mixed;
    final rangePercent = question.chart.vpipPercent.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: color.withValues(alpha: 0.08),
          borderColor: color.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ok ? '○' : '×',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ok ? '正解' : '不正解',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          'あなたの答え: ${result.answer.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isBoundary
                    ? 'レンジ表の答え: ${answers.map((a) => a.label).join(' と ')}'
                          '（境目の手なので、どちらも正解）'
                    : 'レンジ表の答え: ${answers.first.label}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                guidance.reason,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Callout(label: 'こうなら答えが変わる', text: guidance.practicalNote),
              const SizedBox(height: AppSpacing.sm),
              Text(
                question.isOpen
                    ? 'この席のオープンレンジ: 全体の $rangePercent%'
                    : 'この場面で参加する手（コール＋3ベット）: 全体の $rangePercent%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '※ 答えはアプリ同梱のレンジ表（ソルバー系の公開資料を参考にした'
                '学習用の目安）です。',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(isLast ? '結果を見る' : '次の問題'),
        ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.info,
            ),
          ),
          Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.session,
    required this.onRestart,
    required this.onRetryMistakes,
  });

  final PreflopDrillSession session;
  final VoidCallback onRestart;
  final VoidCallback? onRetryMistakes;

  @override
  Widget build(BuildContext context) {
    final rate = (session.correct * 100 / session.answered).round();
    final byPosition = session.byPosition;
    final positions = [
      for (final position in Position.values)
        if (byPosition.containsKey(position)) position,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            children: [
              const Text(
                'セッション結果',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$rate%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: rate >= 80
                      ? AppColors.success
                      : (rate >= 60 ? AppColors.warning : AppColors.danger),
                ),
              ),
              Text(
                '${session.answered} 問中 ${session.correct} 問正解'
                '・最高 ${session.bestStreak} 連続',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '席ごとの正解',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final position in positions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          position.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:
                                byPosition[position]!.$1 /
                                byPosition[position]!.$2,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceHigh,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${byPosition[position]!.$1}/${byPosition[position]!.$2}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (session.mistakes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '間違えた問題',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final mistake in session.mistakes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${mistake.question.spot.heroPosition.label}'
                      '${mistake.question.isOpen ? ' オープン' : ' vs ${mistake.question.spot.villainPosition?.label ?? ''}'}'
                      '　${mistake.question.hand.code}：'
                      'あなた ${mistake.answer.label} → 答え '
                      '${mistake.question.correctAnswers.map((a) => a.label).join('/')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (onRetryMistakes != null) ...[
          FilledButton(
            onPressed: onRetryMistakes,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('間違えた問題だけもう一度'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton(
          onPressed: onRestart,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('新しく 20 問'),
        ),
      ],
    );
  }
}
