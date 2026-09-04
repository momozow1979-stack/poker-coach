import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../models/playing_card.dart';

/// トランプ 1 枚の表示。ボードやヒーローハンドの表示に使う。
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    this.width = 40,
    this.onTap,
  });

  /// null のときは裏面（未選択スロット）として表示する。
  final PlayingCard? card;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final currentCard = card;
    final isRed = currentCard?.suit.isRed ?? false;
    final height = width * 1.4;

    return Semantics(
      button: onTap != null,
      label: currentCard == null ? 'カード未選択' : currentCard.display,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: currentCard == null ? AppColors.surfaceHigh : Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm * 0.7),
            border: Border.all(color: AppColors.border),
            boxShadow: currentCard == null
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: currentCard == null
              ? const Icon(Icons.add, size: 18, color: AppColors.textMuted)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentCard.rank.symbol,
                      style: TextStyle(
                        fontSize: width * 0.46,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: isRed
                            ? const Color(0xFFD03A3A)
                            : const Color(0xFF16202E),
                      ),
                    ),
                    Text(
                      currentCard.suit.symbol,
                      style: TextStyle(
                        fontSize: width * 0.38,
                        height: 1.1,
                        color: isRed
                            ? const Color(0xFFD03A3A)
                            : const Color(0xFF16202E),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// カードを横並びで表示する。
///
/// [dealAnimation] を有効にすると、1 枚ずつめくれるように現れる。
class PlayingCardRow extends StatelessWidget {
  const PlayingCardRow({
    super.key,
    required this.cards,
    this.width = 40,
    this.spacing = AppSpacing.sm,
    this.dealAnimation = false,
    this.dealDelay = Duration.zero,
  });

  final List<PlayingCard> cards;
  final double width;
  final double spacing;
  final bool dealAnimation;

  /// 1 枚目が現れるまでの待ち時間。
  final Duration dealDelay;

  @override
  Widget build(BuildContext context) {
    final animate = dealAnimation && !MediaQuery.disableAnimationsOf(context);
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (var i = 0; i < cards.length; i++)
          if (animate)
            _DealtCard(
              key: ValueKey('${cards[i].code}-$i'),
              card: cards[i],
              width: width,
              delay: dealDelay + Duration(milliseconds: 90 * i),
            )
          else
            PlayingCardView(card: cards[i], width: width),
      ],
    );
  }
}

/// 配られたように現れる 1 枚。
class _DealtCard extends StatefulWidget {
  const _DealtCard({
    super.key,
    required this.card,
    required this.width,
    required this.delay,
  });

  final PlayingCard card;
  final double width;
  final Duration delay;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final value = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Transform.scale(scale: 0.88 + 0.12 * value, child: child),
          ),
        );
      },
      child: PlayingCardView(card: widget.card, width: widget.width),
    );
  }
}
