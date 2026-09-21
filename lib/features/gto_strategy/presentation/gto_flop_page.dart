import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/widgets/app_card.dart';
import '../../range_chart/presentation/widgets/range_cell.dart';
import '../application/gto_flop_providers.dart';
import '../domain/gto_flop_strategy.dart';

/// ベット寄り（＝c-bet 頻度が高い）を表す色。
const Color _betColor = Color(0xFF059669);

/// チェック寄りを表す色。
const Color _checkColor = Color(0xFF64748B);

/// ソルバーで学習したフロップの c-bet 戦略ビューア（13×13 ヒートマップ）。
class GtoFlopPage extends ConsumerStatefulWidget {
  const GtoFlopPage({super.key});

  @override
  ConsumerState<GtoFlopPage> createState() => _GtoFlopPageState();
}

class _GtoFlopPageState extends ConsumerState<GtoFlopPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gtoFlopStrategyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GTOフロップ戦略')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const SizedBox.shrink(),
          data: (strategy) {
            if (strategy.spots.isEmpty) return const SizedBox.shrink();
            final index = _selected.clamp(0, strategy.spots.length - 1);
            final spot = strategy.spots[index];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _boardSelector(strategy, index),
                const SizedBox(height: AppSpacing.lg),
                AspectRatio(aspectRatio: 1, child: _grid(spot)),
                const SizedBox(height: AppSpacing.lg),
                _legend(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _boardSelector(GtoFlopStrategy strategy, int selected) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: strategy.spots.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final isSel = i == selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSel ? AppColors.accent : AppColors.border,
                ),
              ),
              child: _boardLabel(strategy.spots[i].board, onDark: isSel),
            ),
          );
        },
      ),
    );
  }

  Widget _boardLabel(List<PlayingCard> board, {required bool onDark}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final card in board)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              '${card.rank.symbol}${card.suit.symbol}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: onDark
                    ? Colors.white
                    : (card.suit.isRed
                          ? AppColors.danger
                          : AppColors.textPrimary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(GtoFlopSpot spot) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(child: _cell(StartingHand.fromGrid(row, col), spot)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, GtoFlopSpot spot) {
    final bet = spot.betFor(hand.code);
    final Color bg;
    if (bet == null) {
      bg = AppColors.rangeFold;
    } else {
      bg = Color.lerp(_checkColor, _betColor, bet)!;
    }
    return RangeCell(
      code: hand.code,
      topColor: bg,
      bottomColor: bg,
      textColor: bet == null ? AppColors.textMuted : Colors.white,
      onTap: bet == null ? null : () => _showDetail(hand, bet),
    );
  }

  void _showDetail(StartingHand hand, double bet) {
    final betPct = (bet * 100).round();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hand.code}（${hand.description}）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            _bar('ベット', betPct, _betColor),
            const SizedBox(height: AppSpacing.sm),
            _bar('チェック', 100 - betPct, _checkColor),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, int pct, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 14,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend() {
    return AppCard(
      child: Row(
        children: [
          const Text(
            'チェック',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [_checkColor, _betColor],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'ベット',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
