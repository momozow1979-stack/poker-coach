import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/canvas_text.dart';
import '../models/position.dart';
import '../models/table_type.dart';

/// テーブルの席を俯瞰で描く図。
///
/// 「BTN vs BB」のような関係を文字で読ませる代わりに、
/// 円卓のどこに座っているかで一目で分かるようにする。
///
/// [onSeatTap] を渡すと席をタップして選べるようになる。
/// 選択 UI では席が動くと分かりづらいため、そのときは
/// [rotateHeroToBottom] を false にして席順を固定する。
class PokerTableView extends StatelessWidget {
  const PokerTableView({
    super.key,
    required this.tableType,
    required this.heroPosition,
    this.villainPosition,
    this.potLabel,
    this.height = 148,
    this.onSeatTap,
    this.rotateHeroToBottom = true,
  });

  final TableType tableType;

  /// ヒーローの席。未選択を表したい場合は null。
  final Position? heroPosition;
  final Position? villainPosition;

  /// テーブル中央に出す文字（例: `Pot 5.5BB`）。
  final String? potLabel;
  final double height;

  /// 席をタップしたときの処理。null なら表示専用。
  final ValueChanged<Position>? onSeatTap;

  /// ヒーローを手前（下）に配置するか。
  final bool rotateHeroToBottom;

  static const double seatRadius = 17;

  /// 席の並び。ヒーローを手前に置く場合は回転させる。
  static List<Position> seatOrder(
    TableType tableType,
    Position? heroPosition, {
    required bool rotateHeroToBottom,
  }) {
    final seats = Position.orderFor(tableType);
    if (!rotateHeroToBottom || heroPosition == null) return seats;
    final heroIndex = seats.indexOf(heroPosition);
    if (heroIndex < 0) return seats;
    return [
      for (var i = 0; i < seats.length; i++)
        seats[(heroIndex + i) % seats.length],
    ];
  }

  /// 席の中心座標。描画とタップ領域で同じ計算を使う。
  static Offset seatCenter(Size size, int index, int count, double progress) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width / 2 - seatRadius - 10;
    final ry = size.height / 2 - seatRadius - 6;
    // 先頭の席を手前（下）に置き、以降は実際の卓と同じ時計回りに並べる。
    // Canvas は y 軸が下向きなので、角度を足すと画面上では時計回りになる。
    final angle = (math.pi / 2) + (index * 2 * math.pi / count);
    return Offset(
      center.dx + rx * math.cos(angle) * progress,
      center.dy + ry * math.sin(angle) * progress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final seats = seatOrder(
      tableType,
      heroPosition,
      rotateHeroToBottom: rotateHeroToBottom,
    );

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          return TweenAnimationBuilder<double>(
            // 席が中心から広がるように現れる。
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) {
              return Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: _PokerTablePainter(
                      seats: seats,
                      heroPosition: heroPosition,
                      villainPosition: villainPosition,
                      potLabel: potLabel,
                      progress: progress,
                      textDirection: Directionality.of(context),
                      baseStyle: canvasTextStyle(context),
                    ),
                  ),
                  if (onSeatTap != null)
                    for (var i = 0; i < seats.length; i++)
                      _SeatTapTarget(
                        position: seats[i],
                        center: seatCenter(size, i, seats.length, 1),
                        onTap: () => onSeatTap!(seats[i]),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 席の上に重ねる透明なタップ領域。
///
/// 描画は CustomPaint に任せ、当たり判定と読み上げだけをここが持つ。
class _SeatTapTarget extends StatelessWidget {
  const _SeatTapTarget({
    required this.position,
    required this.center,
    required this.onTap,
  });

  final Position position;
  final Offset center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = AppSpacing.minTapTarget;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: '${position.label} を選ぶ',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, customBorder: const CircleBorder()),
        ),
      ),
    );
  }
}

class _PokerTablePainter extends CustomPainter {
  _PokerTablePainter({
    required this.seats,
    required this.heroPosition,
    required this.villainPosition,
    required this.potLabel,
    required this.progress,
    required this.textDirection,
    required this.baseStyle,
  });

  final List<Position> seats;
  final Position? heroPosition;
  final Position? villainPosition;
  final String? potLabel;
  final double progress;
  final TextDirection textDirection;
  final TextStyle baseStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width / 2 - PokerTableView.seatRadius - 10;
    final ry = size.height / 2 - PokerTableView.seatRadius - 6;

    _paintFelt(canvas, center, rx, ry);

    for (var i = 0; i < seats.length; i++) {
      _paintSeat(
        canvas,
        PokerTableView.seatCenter(size, i, seats.length, progress),
        seats[i],
      );
    }

    if (potLabel != null) {
      _paintText(
        canvas,
        potLabel!,
        center,
        color: AppColors.textSecondary,
        fontSize: 12,
        weight: FontWeight.w700,
      );
    }
  }

  void _paintFelt(Canvas canvas, Offset center, double rx, double ry) {
    final rect = Rect.fromCenter(
      center: center,
      width: rx * 2 - 12,
      height: ry * 2 - 12,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.surfaceHigh,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.border,
    );
  }

  void _paintSeat(Canvas canvas, Offset seatCenter, Position position) {
    final isHero = position == heroPosition;
    final isVillain = position == villainPosition;

    final Color fill;
    final Color border;
    final Color label;
    if (isHero) {
      fill = AppColors.accent;
      border = AppColors.accent;
      label = AppColors.onAccent;
    } else if (isVillain) {
      fill = AppColors.info.withValues(alpha: 0.22);
      border = AppColors.info;
      label = AppColors.info;
    } else {
      fill = AppColors.surface;
      border = AppColors.border;
      label = AppColors.textMuted;
    }

    canvas.drawCircle(
      seatCenter,
      PokerTableView.seatRadius,
      Paint()..color = fill,
    );
    canvas.drawCircle(
      seatCenter,
      PokerTableView.seatRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHero || isVillain ? 2 : 1
        ..color = border,
    );

    _paintText(
      canvas,
      position.label,
      seatCenter,
      color: label,
      fontSize: position.label.length > 3 ? 8.5 : 10,
      weight: FontWeight.w800,
    );

    // BTN にはディーラーボタンを添える。
    if (position == Position.btn) {
      final buttonCenter =
          seatCenter + const Offset(0, -PokerTableView.seatRadius - 7);
      canvas.drawCircle(buttonCenter, 6.5, Paint()..color = Colors.white);
      _paintText(
        canvas,
        'D',
        buttonCenter,
        color: const Color(0xFF16202E),
        fontSize: 8,
        weight: FontWeight.w900,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    required FontWeight weight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PokerTablePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.heroPosition != heroPosition ||
      oldDelegate.villainPosition != villainPosition ||
      oldDelegate.potLabel != potLabel ||
      oldDelegate.seats != seats ||
      oldDelegate.baseStyle != baseStyle;
}
