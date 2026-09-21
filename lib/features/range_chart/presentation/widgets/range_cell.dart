import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// レンジ表・暗記ドリルで共通して使う 1 マス。
///
/// [topColor] と [bottomColor] が同じなら単色、違えば左上→右下の対角線で
/// 「右上＝[topColor]（3ベット席）／左下＝[bottomColor]（コール席）」の
/// ツートンで塗る。CSS の `linear-gradient(135deg, top 50%, bottom 50%)` と同じ向き。
class RangeCell extends StatelessWidget {
  const RangeCell({
    super.key,
    required this.code,
    required this.topColor,
    required this.bottomColor,
    this.textColor = Colors.white,
    this.borderColor,
    this.borderWidth = 0.5,
    this.onTap,
  });

  final String code;
  final Color topColor;
  final Color bottomColor;
  final Color textColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final solid = topColor == bottomColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: solid ? topColor : null,
          border: Border.all(
            color: borderColor ?? AppColors.border,
            width: borderWidth,
          ),
        ),
        child: CustomPaint(
          painter: solid
              ? null
              : _DiagonalSplitPainter(
                  topRight: topColor,
                  bottomLeft: bottomColor,
                ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    shadows: solid
                        ? null
                        : const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 1,
                              offset: Offset(0, 0.5),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 左上→右下の対角線で 2 色に塗り分ける。右上が [topRight]、左下が [bottomLeft]。
class _DiagonalSplitPainter extends CustomPainter {
  const _DiagonalSplitPainter({
    required this.topRight,
    required this.bottomLeft,
  });

  final Color topRight;
  final Color bottomLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // 右上の三角形: (0,0)-(w,0)-(w,h)
    paint.color = topRight;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..close(),
      paint,
    );
    // 左下の三角形: (0,0)-(0,h)-(w,h)
    paint.color = bottomLeft;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(0, h)
        ..lineTo(w, h)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DiagonalSplitPainter old) =>
      old.topRight != topRight || old.bottomLeft != bottomLeft;
}
