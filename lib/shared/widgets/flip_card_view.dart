import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../models/playing_card.dart';
import 'playing_card_view.dart';

/// [PlayingCardView] を、裏↔表の切り替え時に 3D で回転させて見せる。
///
/// 表示するカードを差し替えるだけの [PlayingCardView] と違い、
/// 「めくる」動作そのものを演出したい場面（ハンドを配られた直後、
/// ボードが開く瞬間、ショーダウンでの公開）で使う。[faceUp] が変わった
/// ときだけ回転し、変わらなければ静止したまま（初回表示では回転しない）。
class FlipCardView extends StatelessWidget {
  const FlipCardView({
    super.key,
    required this.card,
    required this.faceUp,
    this.width = 40,
  });

  /// 表になったときに見せる柄。[faceUp] が false の間は使わない。
  final PlayingCard? card;
  final bool faceUp;
  final double width;

  @override
  Widget build(BuildContext context) {
    final target = faceUp ? math.pi : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, child) {
        final showingFront = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateY(angle),
          child: showingFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: PlayingCardView(card: card, width: width),
                )
              : _CardBack(width: width),
        );
      },
    );
  }
}

/// 伏せられたカードの裏面。
///
/// [PlayingCardView] の `card: null` は「未選択スロット（＋ボタン）」を
/// 表す別の意味なので、ここでは流用せず専用の見た目を用意する
/// （伏せ札を「まだ入力していない」と誤読されると紛らわしいため）。
class _CardBack extends StatelessWidget {
  const _CardBack({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm * 0.7),
        border: Border.all(color: AppColors.accentDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: width * 0.5,
        height: width * 0.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
