import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../hand_review/domain/hand_read.dart';
import '../../practice_table/domain/grading/decision_grade.dart';
import '../../practice_table/domain/grading/grade_explainer.dart';
import '../../practice_table/presentation/widgets/practice_explanation_view.dart';
import '../application/drill_providers.dart';
import '../domain/bluff_drill_opponent.dart';
import '../domain/bluff_spot.dart';

/// ブラフ練習。
///
/// 相手がチェックしてきて、自分の手が弱い場面で、
/// 1. そもそもブラフ（ベット）するか、あきらめて（チェックして）見るか
/// 2. ブラフするなら、いくら賭けるか
/// を選ぶ。採点は「AI相手に練習」と同じ仕組みで、この相手の打ち方に対する
/// 損得を計算する。1 セッション 5 問。
class BluffDrillPage extends ConsumerStatefulWidget {
  const BluffDrillPage({super.key});

  @override
  ConsumerState<BluffDrillPage> createState() => _BluffDrillPageState();
}

class _BluffDrillPageState extends ConsumerState<BluffDrillPage> {
  static const _length = 5;

  BluffSpot? _spot;
  bool _choosingSize = false;
  PracticeOptionGrade? _chosen;
  int _answered = 0;
  int _points = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _spot = null;
      _chosen = null;
      _choosingSize = false;
    });
    // 「問題を作っています」を一度描いてから重い計算に入る。
    await Future<void>.delayed(const Duration(milliseconds: 32));
    final spot = await ref.read(bluffSpotGeneratorProvider).next();
    if (!mounted) return;
    setState(() => _spot = spot);
  }

  void _choose(PracticeOptionGrade option) {
    setState(() {
      _chosen = option;
      _answered++;
      _points += switch (option.verdict) {
        PracticeVerdict.good => 2,
        PracticeVerdict.close => 1,
        PracticeVerdict.bad => 0,
      };
    });
  }

  void _next() {
    if (_answered >= _length) {
      setState(() => _finished = true);
      return;
    }
    _load();
  }

  void _restart() {
    setState(() {
      _answered = 0;
      _points = 0;
      _finished = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    return Scaffold(
      appBar: AppBar(title: const Text('ブラフ練習')),
      body: SafeArea(
        child: _finished
            ? _Summary(
                points: _points,
                maxPoints: _answered * 2,
                onRestart: _restart,
              )
            : spot == null
            ? const _Loading()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Text(
                        '${_answered + (_chosen == null ? 1 : 0)} / $_length 問',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '$_points 点',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SpotCard(spot: spot),
                  const SizedBox(height: AppSpacing.md),
                  if (_chosen == null)
                    _choosingSize
                        ? _SizeStep(
                            spot: spot,
                            onBack: () => setState(() => _choosingSize = false),
                            onPick: _choose,
                          )
                        : _BluffOrNotStep(
                            onCheck: () => _choose(spot.check),
                            onBet: () => setState(() => _choosingSize = true),
                          )
                  else ...[
                    PracticeExplanationView(
                      explanation: PracticeGradeExplainer.explain(
                        spot.grade,
                        _chosen!,
                      ),
                      chosenLabel: _chosen!.option.label,
                      heroCards: spot.hand.heroCards,
                      board: spot.hand.board,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Comparison(spot: spot, chosen: _chosen!),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_answered >= _length ? '結果を見る' : '次の問題'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('問題を作っています…', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: AppSpacing.sm),
            SizedBox(width: 200, child: LinearProgressIndicator(minHeight: 6)),
          ],
        ),
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot});

  final BluffSpot spot;

  @override
  Widget build(BuildContext context) {
    final hand = spot.hand;
    final read = HandRead.of(hand.heroCards, hand.board);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            '${hand.street.label}。相手（BB）はチェックしてきました',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'あなたは BTN でオープンし、BB にコールされたハンドです',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          PokerTableView(
            tableType: hand.tableType,
            heroPosition: hand.heroPosition,
            villainPosition: hand.villainPosition,
            potLabel: 'Pot ${formatBb(hand.pot)}BB',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 4,
            children: [
              for (final card in hand.board)
                PlayingCardView(card: card, width: 40),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final card in hand.heroCards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: PlayingCardView(card: card, width: 48),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'あなたの手: ${read.label}'
            '${read.draws.isEmpty ? '' : '・${read.draws.join('・')}'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.only(bottom: AppSpacing.sm),
              title: Text(
                'この練習の相手の打ち方',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              children: [
                Text(
                  BluffDrillOpponent.description,
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BluffOrNotStep extends StatelessWidget {
  const _BluffOrNotStep({required this.onCheck, required this.onBet});

  final VoidCallback onCheck;
  final VoidCallback onBet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ブラフしますか？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const Text(
          'チェックしたら、最後までお互いチェックで進む前提で計算します',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCheck,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('チェック'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: onBet,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('ブラフする'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SizeStep extends StatelessWidget {
  const _SizeStep({
    required this.spot,
    required this.onBack,
    required this.onPick,
  });

  final BluffSpot spot;
  final VoidCallback onBack;
  final ValueChanged<PracticeOptionGrade> onPick;

  @override
  Widget build(BuildContext context) {
    final pot = spot.hand.pot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'ブラフするか選び直す',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const Expanded(
              child: Text(
                'いくら賭けますか？',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        for (final bet in spot.bets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FilledButton.tonal(
              onPressed: () => onPick(bet),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                '${formatBb(bet.option.sizeBb!)}BB'
                '（ポットの ${(bet.option.sizeBb! / pot * 100).round()}%）',
              ),
            ),
          ),
      ],
    );
  }
}

/// 選択肢ごとの数字の比較（チェックと各ベット額）。
class _Comparison extends StatelessWidget {
  const _Comparison({required this.spot, required this.chosen});

  final BluffSpot spot;
  final PracticeOptionGrade chosen;

  @override
  Widget build(BuildContext context) {
    final best = spot.best;
    final pot = spot.hand.pot;
    String pct(double? value) =>
        value == null ? '—' : '${(value * 100).round()}%';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '選択肢ごとの比較（この相手に対して）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '「降りる」はこの額に相手が降りる割合、「必要」は降ろすだけで元が取れる'
            '割合（賭ける額 ÷（ポット＋賭ける額））。損は一番得な選択との差です。',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final option in [spot.check, ...spot.bets])
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: identical(option, chosen)
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      option.verdict.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: practiceVerdictColor(option.verdict),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.option.action == PokerActionType.check
                              ? 'チェック'
                              : 'ベット ${formatBb(option.option.sizeBb!)}BB'
                                    '（${(option.option.sizeBb! / pot * 100).round()}%）',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (option.option.action == PokerActionType.bet)
                          Text(
                            '降りる ${pct(option.foldRate)}・必要 '
                            '${pct(option.breakEvenFoldRate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    identical(option, best)
                        ? '一番得'
                        : '損 ${formatBb(((option.lossBb ?? 0) * 4).round() / 4)}BB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: identical(option, best)
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (chosen.option.action == PokerActionType.bet && !spot.shouldBluff)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'ここは賭けないほうが得な場面でした。降ろせる割合が足りないか、'
                'チェックしてショーダウンまで行けば勝てる分のほうが大きいためです。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.points,
    required this.maxPoints,
    required this.onRestart,
  });

  final int points;
  final int maxPoints;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
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
                '$points / $maxPoints 点',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '○ 2点・△ 1点・× 0点',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onRestart,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('もう一度 5 問'),
        ),
      ],
    );
  }
}
