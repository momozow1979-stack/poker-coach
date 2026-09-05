import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../models/poker_action.dart';

/// [ActionFrequencyBar] の1区間。
///
/// [share] は他の区間との相対的な重みで、呼び出し側で正規化しておく
/// 必要はない（合計 1.0 でも、合計 100 でもよい。表示側で割合に直す）。
class ActionFrequencySegment {
  const ActionFrequencySegment({required this.actionType, required this.share})
    : assert(share >= 0, '頻度は0以上である必要があります');

  final PokerActionType actionType;
  final double share;
}

/// 複数アクションの頻度を、1本の帯グラフに色分けして積み上げる。
///
/// 単一値の帯である `LabeledProgressBar` を、複数区間に拡張したもの。
/// 色だけに頼ると色覚特性のある人や白黒表示で読めなくなるため、
/// 各区間には必ずアイコン + アクション名 + パーセントの凡例を添える
/// （`RangeAction` の既存方針と同じ考え方）。
class ActionFrequencyBar extends StatelessWidget {
  const ActionFrequencyBar({super.key, required this.segments, this.label});

  /// 表示する区間。0件、または合計が0以下なら何も描画しない。
  final List<ActionFrequencySegment> segments;

  /// 帯の上に出す見出し（例:「このスポットでの選択肢」）。省略可。
  final String? label;

  double get _total => segments.fold(0.0, (sum, s) => sum + s.share);

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final visible = [
      for (final segment in segments)
        if (segment.share > 0) segment,
    ];
    if (visible.isEmpty || total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 22,
            child: Row(
              children: [
                for (final segment in visible)
                  Expanded(
                    // Expanded の flex は正の整数のみ受け付けるため、
                    // 割合を1000分率に丸めて渡す（実際の表示比率は
                    // 丸め誤差レベルの差にしかならない）。
                    flex: ((segment.share / total) * 1000).round().clamp(
                      1,
                      1000,
                    ),
                    child: Semantics(
                      label:
                          '${segment.actionType.label} '
                          '${_percentLabel(segment.share, total)}%',
                      child: ColoredBox(color: segment.actionType.color),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 4,
          children: [
            for (final segment in visible)
              _Legend(
                actionType: segment.actionType,
                percent: _percentLabel(segment.share, total),
              ),
          ],
        ),
      ],
    );
  }

  static int _percentLabel(double share, double total) =>
      (share / total * 100).round();
}

class _Legend extends StatelessWidget {
  const _Legend({required this.actionType, required this.percent});

  final PokerActionType actionType;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(actionType.icon, size: 14, color: actionType.color),
        const SizedBox(width: 4),
        Text(
          '${actionType.label} $percent%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
