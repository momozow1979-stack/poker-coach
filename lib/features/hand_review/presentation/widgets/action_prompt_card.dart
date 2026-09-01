import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/poker_action.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/hand_flow.dart';

/// 「いま誰が、何を選べるか」を出して、1 手ずつ受け取るカード。
///
/// 誰の番かはポジションから決まるので選ばせない。
/// ベットやレイズの額は任意で、分からなければ飛ばせる。
class ActionPromptCard extends StatefulWidget {
  const ActionPromptCard({
    super.key,
    required this.prompt,
    required this.onAdd,
  });

  final ActionPrompt prompt;

  /// 額は分からなければ null。
  final void Function(PokerActionType action, double? sizeBb) onAdd;

  @override
  State<ActionPromptCard> createState() => _ActionPromptCardState();
}

class _ActionPromptCardState extends State<ActionPromptCard> {
  /// 額の入力待ちになっているアクション。null なら通常の選択中。
  PokerActionType? _pending;
  final _sizeController = TextEditingController();

  @override
  void didUpdateWidget(ActionPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 場面が変わったら額の入力状態を持ち越さない。
    if (oldWidget.prompt.street != widget.prompt.street ||
        oldWidget.prompt.actor != widget.prompt.actor) {
      _reset();
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }

  void _reset() {
    _pending = null;
    _sizeController.clear();
  }

  void _choose(PokerActionType action) {
    if (action == PokerActionType.bet ||
        action == PokerActionType.raise ||
        action == PokerActionType.allIn) {
      setState(() => _pending = action);
      return;
    }
    widget.onAdd(action, null);
  }

  void _commit(double? sizeBb) {
    final action = _pending;
    if (action == null) return;
    widget.onAdd(action, sizeBb);
    setState(_reset);
  }

  /// 額を入れやすくするための候補。分かる範囲でしか出さない。
  List<(String, double)> get _quickSizes {
    final prompt = widget.prompt;
    if (_pending == PokerActionType.allIn) return const [];

    if (prompt.street.name == 'preflop' && !prompt.facingBet) return const [];

    // プリフロップの最初のレイズは BB 基準のほうが分かりやすい。
    if (prompt.aggressiveLabel == 'レイズ' && prompt.currentBetBb == 1) {
      return const [('2BB', 2), ('2.5BB', 2.5), ('3BB', 3), ('4BB', 4)];
    }

    final currentBet = prompt.currentBetBb;
    if (prompt.facingBet && currentBet != null && currentBet > 0) {
      return [
        ('${HandAction.formatBb(currentBet * 2.5)}BB', currentBet * 2.5),
        ('${HandAction.formatBb(currentBet * 3)}BB', currentBet * 3),
      ];
    }

    final pot = prompt.potBb;
    if (!prompt.facingBet && pot != null && pot > 0) {
      return [
        ('ポットの1/3', _round(pot / 3)),
        ('ポットの1/2', _round(pot / 2)),
        ('ポットの2/3', _round(pot * 2 / 3)),
        ('ポット', _round(pot)),
      ];
    }
    return const [];
  }

  static double _round(double value) => (value * 2).round() / 2;

  @override
  Widget build(BuildContext context) {
    final prompt = widget.prompt;
    final accent = prompt.isHero ? AppColors.accent : AppColors.info;

    return AppCard(
      borderColor: accent.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${prompt.street.label}：'
                  '${prompt.position.label}（${prompt.actorLabel}）の番です',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Situation(prompt: prompt),
          const SizedBox(height: AppSpacing.md),
          if (_pending == null)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final choice in prompt.choices)
                  _ActionButton(
                    label: _labelFor(choice, prompt),
                    emphasized: choice == PokerActionType.fold,
                    onTap: () => _choose(choice),
                  ),
              ],
            )
          else
            _SizeInput(
              title: _pending == PokerActionType.allIn
                  ? 'オールイン：いくら入れた？'
                  : '${prompt.aggressiveLabel}：いくらまで上げた？',
              controller: _sizeController,
              quickSizes: _quickSizes,
              onCommit: _commit,
              onCancel: () => setState(_reset),
            ),
        ],
      ),
    );
  }

  static String _labelFor(PokerActionType action, ActionPrompt prompt) {
    return switch (action) {
      PokerActionType.fold => 'フォールド',
      PokerActionType.check => 'チェック',
      PokerActionType.call =>
        prompt.toCallBb == null
            ? 'コール'
            : 'コール ${HandAction.formatBb(prompt.toCallBb!)}BB',
      PokerActionType.bet || PokerActionType.raise => prompt.aggressiveLabel,
      PokerActionType.allIn => 'オールイン',
    };
  }
}

/// ポット・コール額・必要勝率。分かるものだけ出す。
class _Situation extends StatelessWidget {
  const _Situation({required this.prompt});

  final ActionPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final pot = prompt.potBb;
    final toCall = prompt.toCallBb;
    final equity = prompt.requiredEquity;

    final parts = <String>[
      if (pot != null) 'ポット ${HandAction.formatBb(pot)}BB',
      if (toCall != null) 'コールに ${HandAction.formatBb(toCall)}BB',
      if (pot == null) 'ポットは不明（額を入れると計算されます）',
    ];

    // ブラインドを埋めるだけの場面では、ポットオッズの話をしない。
    final blindNote = prompt.isBlindOnly && toCall != null
        ? 'BB を埋めるぶんなので、まだポットオッズの話ではありません'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.join(' ・ '),
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (blindNote != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            blindNote,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
        if (equity != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'このコールに必要な勝率は約${(equity * 100).round()}%です',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ],
    );
  }
}

/// 額の入力。分からなければ飛ばせる。
class _SizeInput extends StatelessWidget {
  const _SizeInput({
    required this.title,
    required this.controller,
    required this.quickSizes,
    required this.onCommit,
    required this.onCancel,
  });

  final String title;
  final TextEditingController controller;
  final List<(String, double)> quickSizes;
  final ValueChanged<double?> onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('戻る')),
          ],
        ),
        if (quickSizes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (label, value) in quickSizes)
                _ActionButton(label: label, onTap: () => onCommit(value)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '例）12',
                  suffixText: 'BB',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onSubmitted: (text) => onCommit(double.tryParse(text.trim())),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () =>
                  onCommit(double.tryParse(controller.text.trim())),
              child: const Text('決定'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onCommit(null),
              child: const Text('分からない'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;

  /// フォールドのように、押すと後戻りしにくいものを控えめに見せる。
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Material(
      color: emphasized ? AppColors.surface : AppColors.surfaceHigh,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // Container に alignment を渡すと横幅いっぱいに広がる。
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget,
            minWidth: 76,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: emphasized ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
