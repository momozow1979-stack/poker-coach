import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../application/practice_providers.dart';
import '../domain/practice_hand_state.dart';
import 'practice_history_page.dart';

/// AI（ヴィラン）相手のリアルタイム練習画面。
///
/// v1 はヒーロー固定で BTN・ヴィランが BB のオープン練習のみ
/// （[practiceHeroPosition] / [practiceVillainPosition] 参照）。
class PracticeTablePage extends ConsumerStatefulWidget {
  const PracticeTablePage({super.key});

  @override
  ConsumerState<PracticeTablePage> createState() => _PracticeTablePageState();
}

class _PracticeTablePageState extends ConsumerState<PracticeTablePage> {
  @override
  void initState() {
    super.initState();
    // 画面を開いた時点でまだ何も始まっていなければ、最初のハンドを配る。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(practiceTableProvider) == null) {
        ref.read(practiceTableProvider.notifier).startNewHand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(practiceTableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI相手に練習'),
        actions: [
          IconButton(
            tooltip: '履歴',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PracticeHistoryPage()),
            ),
          ),
        ],
      ),
      body: snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: _PracticeBody(snapshot: snapshot)),
    );
  }
}

class _PracticeBody extends ConsumerWidget {
  const _PracticeBody({required this.snapshot});

  final PracticeTableSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hand = snapshot.hand;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                PokerTableView(
                  tableType: hand.tableType,
                  heroPosition: hand.heroPosition,
                  villainPosition: hand.villainPosition,
                  potLabel: 'Pot ${_formatBb(hand.pot)}BB',
                ),
                const SizedBox(height: AppSpacing.lg),
                _HandCards(hand: hand),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.isOpponentThinking) const _ThinkingIndicator(),
                if (hand.isOver) _ResultBanner(hand: hand),
              ],
            ),
          ),
        ),
        if (!hand.isOver && hand.isHeroTurn) _ActionBar(hand: hand),
        if (hand.isOver)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    ref.read(practiceTableProvider.notifier).startNewHand(),
                child: const Text('次のハンド'),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatBb(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class _HandCards extends StatelessWidget {
  const _HandCards({required this.hand});

  final PracticeHandState hand;

  @override
  Widget build(BuildContext context) {
    // ヴィランの手札は、ハンドが終わってショーダウンになるまで隠す
    // （練習として実戦に近づけるため。フォールドで終わったときは
    // 最後まで見せない — 実戦でも降りた側の手札は分からない）。
    final revealVillain = hand.sawShowdown;

    return Column(
      children: [
        _PlayerRow(
          label: '相手（${hand.villainPosition.label}）',
          cards: revealVillain
              ? <PlayingCard?>[...hand.villainCards]
              : const <PlayingCard?>[null, null],
        ),
        const SizedBox(height: AppSpacing.md),
        if (hand.board.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final card in hand.board)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: PlayingCardView(card: card, width: 36),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        _PlayerRow(
          label: 'あなた（${hand.heroPosition.label}）',
          cards: <PlayingCard?>[...hand.heroCards],
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.label, required this.cards});

  final String label;
  final List<PlayingCard?> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: PlayingCardView(card: card, width: 44),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('相手が考え中…', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.hand});

  final PracticeHandState hand;

  @override
  Widget build(BuildContext context) {
    final won = hand.winner == Actor.hero;
    final label = hand.winner == null ? '引き分け' : (won ? 'あなたの勝ち' : 'あなたの負け');
    final reason = hand.endedByFold
        ? '（相手のフォールド）'
        : (hand.winner == null ? '（ショーダウンで分け）' : '（ショーダウン）');

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            '$label $reason',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('最終ポット ${hand.pot}BB'),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.hand});

  final PracticeHandState hand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = hand.choices;
    if (choices == null) return const SizedBox.shrink();
    final controller = ref.read(practiceTableProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (choices.facingBet)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('コール ${choices.toCallBb}BB'),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final action in choices.choices)
                if (action == PokerActionType.bet ||
                    action == PokerActionType.raise)
                  for (final size in choices.presetSizesBb)
                    _ActionButton(
                      action: action,
                      label: '${action.description} ${_formatBb(size)}',
                      onPressed: () => controller.heroAct(action, sizeBb: size),
                    )
                else
                  _ActionButton(
                    action: action,
                    label: action.description,
                    onPressed: () => controller.heroAct(action),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBb(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.label,
    required this.onPressed,
  });

  final PokerActionType action;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(action.icon, size: 18, color: action.color),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: action.color),
    );
  }
}
