import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/collapsible_section.dart';
import '../../domain/quiz.dart';
import '../../domain/quiz_category.dart';

/// 回答後の解説。
///
/// 最初に見せるのは「正解かどうか」と「短い理由」だけにして、
/// GTO / 実戦 / よくあるミスは畳んでおく。
class QuizExplanationView extends StatelessWidget {
  const QuizExplanationView({
    super.key,
    required this.quiz,
    required this.isCorrect,
    this.onOpenRange,
  });

  final Quiz quiz;
  final bool isCorrect;

  /// 関連するレンジ表を開く。null なら表示しない。
  final VoidCallback? onOpenRange;

  @override
  Widget build(BuildContext context) {
    final explanation = quiz.explanation;
    final isTerm = quiz.category == QuizCategory.terminology;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultBanner(isCorrect: isCorrect, quiz: quiz),
        const SizedBox(height: AppSpacing.md),
        _ReasonCard(body: explanation.shortReason),
        const SizedBox(height: AppSpacing.sm),
        const _MoreLabel(),
        const SizedBox(height: AppSpacing.sm),
        // 用語問題は状況を伴わないので、見出しも言葉の説明に合わせる。
        CollapsibleSection(
          icon: isTerm ? Icons.psychology_outlined : Icons.functions_rounded,
          title: isTerm ? 'なぜ大事か' : 'GTO視点',
          body: explanation.gtoView,
          accent: AppColors.info,
        ),
        CollapsibleSection(
          icon: Icons.sports_esports_rounded,
          title: isTerm ? '実戦での使いどころ' : '実戦での調整',
          body: explanation.practicalView,
          accent: AppColors.warning,
        ),
        CollapsibleSection(
          icon: Icons.error_outline_rounded,
          title: isTerm ? 'よくある勘違い' : 'よくある初心者のミス',
          body: explanation.commonMistake,
          accent: AppColors.danger,
        ),
        if (onOpenRange != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenRange,
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              label: const Text('関連するレンジ表を見る'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 正解 / 不正解のバナー。開いた瞬間に少し弾んで結果を印象づける。
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isCorrect, required this.quiz});

  final bool isCorrect;
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.success : AppColors.danger;
    final banner = AppCard(
      color: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 30,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? '正解' : '不正解',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quiz.category == QuizCategory.terminology
                      ? '正解: ${quiz.correctChoice.label}'
                      : '正しいアクション: ${quiz.correctChoice.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return banner;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.scale(scale: 0.94 + 0.06 * clamped, child: child),
        );
      },
      child: banner,
    );
  }
}

/// 最初から開いておく「理由」。ここだけ読めば次に進める分量にする。
class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '理由',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreLabel extends StatelessWidget {
  const _MoreLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.unfold_more_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'タップでもっと詳しく',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
