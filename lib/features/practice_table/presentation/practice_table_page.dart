import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/widgets/flip_card_view.dart';
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
                  lastAction: _lastChipAction(hand),
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

  /// チップがポットへ動くアニメーションを [PokerTableView] に演出させる
  /// もと。チェック / フォールドはチップが動かないので対象外にする。
  /// [TableLastAction.sequence] にここまでのアクション数を渡すことで、
  /// 同じ人が同じ種類の行動を連続でしても毎回アニメーションが再生される。
  static TableLastAction? _lastChipAction(PracticeHandState hand) {
    if (hand.actions.isEmpty) return null;
    final last = hand.actions.last;
    final movesChips =
        last.action == PokerActionType.call || last.action.isAggressive;
    if (!movesChips) return null;
    return TableLastAction(
      position: last.actor == Actor.hero
          ? hand.heroPosition
          : hand.villainPosition,
      actionType: last.action,
      sequence: hand.actions.length,
    );
  }
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
    final villainKey =
        '${hand.villainCards[0].code}${hand.villainCards[1].code}';

    return Column(
      children: [
        _PlayerRow(
          label: '相手（${hand.villainPosition.label}）',
          cardWidgets: [
            for (var i = 0; i < hand.villainCards.length; i++)
              FlipCardView(
                key: ValueKey('villain-$villainKey-$i'),
                card: hand.villainCards[i],
                faceUp: revealVillain,
                width: 44,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (hand.board.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final card in hand.board)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DealtCard(
                    key: ValueKey('board-${card.code}-${hand.street.id}'),
                    card: card,
                    width: 36,
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        _PlayerRow(
          label: 'あなた（${hand.heroPosition.label}）',
          cardWidgets: [
            for (var i = 0; i < hand.heroCards.length; i++)
              _DealtCard(
                key: ValueKey(
                  'hero-${hand.heroCards[0].code}${hand.heroCards[1].code}-$i',
                ),
                card: hand.heroCards[i],
                width: 44,
                delay: Duration(milliseconds: 220 + i * 140),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.label, required this.cardWidgets});

  final String label;
  final List<Widget> cardWidgets;

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
            for (final widget in cardWidgets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: widget,
              ),
          ],
        ),
      ],
    );
  }
}

/// 配られた直後、一呼吸おいてから裏→表に自動でめくれるカード。
///
/// ヒーロー自身の手札（配られてすぐ確認する動作）と、新しいストリートで
/// 開くボードカードに使う。[key] に「そのカードが配られたこと」を表す
/// 値を渡すことで、同じ内容のまま再描画されても再生され直さないように
/// している（[State] が使い回されるので [_faceUp] は保持されたまま）。
class _DealtCard extends StatefulWidget {
  const _DealtCard({
    super.key,
    required this.card,
    this.width = 40,
    this.delay = const Duration(milliseconds: 260),
  });

  final PlayingCard card;
  final double width;
  final Duration delay;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard> {
  bool _faceUp = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _faceUp = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlipCardView(
      card: widget.card,
      faceUp: _faceUp,
      width: widget.width,
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
