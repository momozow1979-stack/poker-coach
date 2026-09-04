import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/playing_card.dart';
import '../../../../shared/models/starting_hand.dart';
import '../../domain/range_action.dart';
import '../../domain/range_entry.dart';

/// 169 ハンドの 13x13 マトリクス。
///
/// マス目は画面幅に合わせて縮むため、[InteractiveViewer] で拡大できるようにしている。
/// タップ領域 44px の要件は、周囲の操作ボタン側で担保する。
class RangeMatrix extends StatelessWidget {
  const RangeMatrix({super.key, required this.chart, required this.onHandTap});

  final RangeChart chart;
  final ValueChanged<StartingHand> onHandTap;

  @override
  Widget build(BuildContext context) {
    final ranks = CardRank.descending;

    return InteractiveViewer(
      maxScale: 4,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / ranks.length;
            return Column(
              children: [
                for (var row = 0; row < ranks.length; row++)
                  Row(
                    children: [
                      for (var column = 0; column < ranks.length; column++)
                        _MatrixCell(
                          size: cellSize,
                          entry: chart.entryFor(
                            StartingHand.fromGrid(row, column),
                          ),
                          onTap: onHandTap,
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.size,
    required this.entry,
    required this.onTap,
  });

  final double size;
  final RangeEntry entry;
  final ValueChanged<StartingHand> onTap;

  @override
  Widget build(BuildContext context) {
    final isFold = entry.action == RangeAction.fold;
    final blend = entry.blend;
    final symbol = blend == null
        ? entry.action.symbol
        : '${blend.primary.symbol}/${blend.secondary.symbol}';
    final semanticsLabel = blend == null
        ? '${entry.hand.code} ${entry.action.label}'
        : '${entry.hand.code} ${blend.primary.label} '
              '${(blend.primaryShare * 100).round()}% '
              '${blend.secondary.label} '
              '${(blend.secondaryShare * 100).round()}%';

    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: GestureDetector(
          onTap: () => onTap(entry.hand),
          child: Container(
            margin: const EdgeInsets.all(0.5),
            clipBehavior: blend == null ? Clip.none : Clip.antiAlias,
            decoration: BoxDecoration(
              color: blend != null
                  ? null
                  : (isFold
                        ? AppColors.rangeFold
                        : entry.action.color.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (blend != null) _MixedFill(blend: blend),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.hand.code,
                      style: TextStyle(
                        fontSize: size * 0.3,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: isFold ? AppColors.textMuted : Colors.white,
                      ),
                    ),
                    if (!isFold)
                      Text(
                        symbol,
                        style: TextStyle(
                          fontSize: blend == null ? size * 0.24 : size * 0.19,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// MIX ハンドの塗り分け。[RangeActionBlend.primaryShare] に応じて
/// 主アクション色と副アクション色を上下 2 段に塗り分ける。
///
/// 色だけに頼らないという既存方針を維持するため、記号（[_MatrixCell]側で
/// 両方のアクションの頭文字を併記）と併用する。
class _MixedFill extends StatelessWidget {
  const _MixedFill({required this.blend});

  final RangeActionBlend blend;

  @override
  Widget build(BuildContext context) {
    final primaryFlex = (blend.primaryShare * 100).round().clamp(1, 99);
    final secondaryFlex = 100 - primaryFlex;
    return Column(
      children: [
        Expanded(
          flex: primaryFlex,
          child: ColoredBox(color: blend.primary.color.withValues(alpha: 0.85)),
        ),
        Expanded(
          flex: secondaryFlex,
          child: ColoredBox(
            color: blend.secondary.color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
