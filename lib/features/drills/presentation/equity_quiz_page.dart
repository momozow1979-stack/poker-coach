import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../application/drill_providers.dart';
import '../domain/equity_quiz.dart';

/// 勝率クイズ。自分と相手の手札・ボードを見て、リバーまでの勝率を当てる。
///
/// 1 セッション 10 問。答えると、数え上げた厳密な勝率と、
/// アウツ（逆転できるカード）と「2 と 4 の法則」の目安を出す。
class EquityQuizPage extends ConsumerStatefulWidget {
  const EquityQuizPage({super.key});

  @override
  ConsumerState<EquityQuizPage> createState() => _EquityQuizPageState();
}

class _EquityQuizPageState extends ConsumerState<EquityQuizPage> {
  static const _length = 10;

  late EquityQuizQuestion _question;
  int? _picked;
  int _answered = 0;
  int _correct = 0;

  /// 当てた勝率と本当の勝率の差（ポイント）の合計。感覚のずれの目安。
  double _totalGap = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _question = ref.read(equityQuizGeneratorProvider).next();
  }

  void _pick(int choice) {
    if (_picked != null) return;
    setState(() {
      _picked = choice;
      _answered++;
      if (choice == _question.answer) _correct++;
      _totalGap += (choice - _question.equity * 100).abs();
    });
  }

  void _next() {
    setState(() {
      if (_answered >= _length) {
        _finished = true;
        return;
      }
      _picked = null;
      _question = ref.read(equityQuizGeneratorProvider).next();
    });
  }

  void _restart() {
    setState(() {
      _answered = 0;
      _correct = 0;
      _totalGap = 0;
      _finished = false;
      _picked = null;
      _question = ref.read(equityQuizGeneratorProvider).next();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('勝率クイズ')),
      body: SafeArea(
        child: _finished
            ? _Summary(
                correct: _correct,
                total: _answered,
                averageGap: _totalGap / _answered,
                onRestart: _restart,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Text(
                        '${_answered + (_picked == null ? 1 : 0)} / $_length 問',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '正解 $_correct',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Board(question: _question),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _question.isFlop
                        ? 'リバーまで（あと 2 枚）行ったとき、あなたの勝率に一番近いのは？'
                        : 'リバーまで（あと 1 枚）行ったとき、あなたの勝率に一番近いのは？',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Choices(question: _question, picked: _picked, onPick: _pick),
                  if (_picked != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Explanation(question: _question, picked: _picked!),
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

String _cardsText(List<PlayingCard> cards) =>
    cards.map((card) => '${card.rank.symbol}${card.suit.symbol}').join(' ');

class _Board extends StatelessWidget {
  const _Board({required this.question});

  final EquityQuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _HandRow(
            label: '相手',
            cards: question.villain,
            read: question.villainRead.label,
            draws: question.villainRead.draws,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            question.isFlop ? 'フロップ' : 'ターン',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 4,
            children: [
              for (final card in question.board)
                PlayingCardView(card: card, width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HandRow(
            label: 'あなた',
            cards: question.hero,
            read: question.heroRead.label,
            draws: question.heroRead.draws,
          ),
        ],
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({
    required this.label,
    required this.cards,
    required this.read,
    required this.draws,
  });

  final String label;
  final List<PlayingCard> cards;
  final String read;
  final List<String> draws;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PlayingCardView(card: card, width: 40),
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                read,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final draw in draws)
                Text(
                  draw,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.question,
    required this.picked,
    required this.onPick,
  });

  final EquityQuizQuestion question;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final choice in question.choices) ...[
          if (choice != question.choices.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ChoiceButton(
              label: '$choice%',
              state: picked == null
                  ? _ChoiceState.open
                  : (choice == question.answer
                        ? _ChoiceState.correct
                        : (choice == picked
                              ? _ChoiceState.wrong
                              : _ChoiceState.idle)),
              onPressed: () => onPick(choice),
            ),
          ),
        ],
      ],
    );
  }
}

enum _ChoiceState { open, correct, wrong, idle }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      _ChoiceState.open => (null, null),
      _ChoiceState.correct => (AppColors.success, Colors.white),
      _ChoiceState.wrong => (AppColors.danger, Colors.white),
      _ChoiceState.idle => (AppColors.surfaceHigh, AppColors.textMuted),
    };
    return FilledButton.tonal(
      onPressed: state == _ChoiceState.open ? onPressed : () {},
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: background,
        foregroundColor: foreground,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.question, required this.picked});

  final EquityQuizQuestion question;
  final int picked;

  @override
  Widget build(BuildContext context) {
    final ok = picked == question.answer;
    final color = ok ? AppColors.success : AppColors.danger;
    final exact = (question.equity * 100).toStringAsFixed(1);
    final outs = question.outs;
    final multiplier = question.isFlop ? 4 : 2;

    return AppCard(
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok ? '○ 正解' : '× おしい',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'あなたの勝率は $exact%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            '残りのボード全 ${question.runoutCount} 通りを数えた値です'
            '（引き分けは半分として数えています）。',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (outs != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              outs.heroIsBehind
                  ? 'いまはあなたが負けています。次の 1 枚で逆転できるカード（アウツ）は '
                        '${outs.count} 枚。'
                  : 'いまはあなたが勝っています。相手が次の 1 枚で逆転できるカード'
                        '（相手のアウツ）は ${outs.count} 枚。',
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            if (outs.count > 0)
              Text(
                _cardsText(outs.cards),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '目安の出し方（2 と 4 の法則）: アウツ × $multiplier'
                '（${question.isFlop ? 'フロップ＝あと 2 枚' : 'ターン＝あと 1 枚'}）'
                ' = ${outs.count} × $multiplier ≈ ${outs.count * multiplier}%。'
                '${outs.heroIsBehind ? 'これがあなたの勝率のおおよその目安' : '100% からこれを引いたのが、あなたの勝率のおおよその目安'}'
                'です。2 枚目で逆転し返される分などは入らないので、ずれることもあります。',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.correct,
    required this.total,
    required this.averageGap,
    required this.onRestart,
  });

  final int correct;
  final int total;
  final double averageGap;
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
                '$correct / $total',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '選んだ勝率と本当の勝率のずれ: 平均 ${averageGap.toStringAsFixed(1)} ポイント',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onRestart,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('もう一度 10 問'),
        ),
      ],
    );
  }
}
