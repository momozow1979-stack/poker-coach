import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/playing_card.dart';

/// カードをタップで選ぶシート。テキスト入力を使わないための中心的な UI。
class CardPickerSheet extends StatefulWidget {
  const CardPickerSheet({
    super.key,
    required this.title,
    required this.maxCount,
    required this.initialSelection,
    required this.disabledCards,
  });

  final String title;

  /// 選択できる枚数。
  final int maxCount;
  final List<PlayingCard> initialSelection;

  /// 他の場所で既に使われているカード。
  final Set<PlayingCard> disabledCards;

  @override
  State<CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends State<CardPickerSheet> {
  late List<PlayingCard> _selected = [...widget.initialSelection];

  void _toggle(PlayingCard card) {
    setState(() {
      if (_selected.contains(card)) {
        _selected = [..._selected]..remove(card);
      } else if (_selected.length < widget.maxCount) {
        _selected = [..._selected, card];
      } else {
        // 上限に達していたら、最後の 1 枚を置き換える。
        _selected = [..._selected.sublist(0, widget.maxCount - 1), card];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_selected.length} / ${widget.maxCount} 枚選択中',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final suit in CardSuit.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            for (final rank in CardRank.descending)
                              Expanded(
                                child: _PickerCell(
                                  card: PlayingCard(rank, suit),
                                  isSelected: _selected.contains(
                                    PlayingCard(rank, suit),
                                  ),
                                  isDisabled:
                                      widget.disabledCards.contains(
                                        PlayingCard(rank, suit),
                                      ) &&
                                      !_selected.contains(
                                        PlayingCard(rank, suit),
                                      ),
                                  onTap: _toggle,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selected = []),
                    child: const Text('クリア'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('決定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.card,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final PlayingCard card;
  final bool isSelected;
  final bool isDisabled;
  final ValueChanged<PlayingCard> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Opacity(
        opacity: isDisabled ? 0.25 : 1,
        child: GestureDetector(
          onTap: isDisabled ? null : () => onTap(card),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.rank.symbol,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  card.suit.symbol,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.05,
                    color: isSelected
                        ? AppColors.onAccent
                        : (card.suit.isRed
                              ? AppColors.danger
                              : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// カードピッカーを開いて選択結果を返す。キャンセル時は null。
Future<List<PlayingCard>?> showCardPicker(
  BuildContext context, {
  required String title,
  required int maxCount,
  required List<PlayingCard> initialSelection,
  required Set<PlayingCard> disabledCards,
}) {
  return showModalBottomSheet<List<PlayingCard>>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (context) => CardPickerSheet(
      title: title,
      maxCount: maxCount,
      initialSelection: initialSelection,
      disabledCards: disabledCards,
    ),
  );
}
