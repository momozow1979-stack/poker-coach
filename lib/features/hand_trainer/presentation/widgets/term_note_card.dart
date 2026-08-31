import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/trainer_scenario.dart';

/// 設問に出てくる用語の補足。
///
/// 初心者が言葉で詰まったまま選ばされるのを防ぐ。
/// 最初は用語名だけを並べ、タップしたものだけ意味を出す。
class TermNoteCard extends StatefulWidget {
  const TermNoteCard({super.key, required this.terms});

  final List<TermNote> terms;

  @override
  State<TermNoteCard> createState() => _TermNoteCardState();
}

class _TermNoteCardState extends State<TermNoteCard> {
  int? _openIndex;

  @override
  void didUpdateWidget(TermNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 設問が変わったら開きっぱなしにしない。
    if (oldWidget.terms != widget.terms) _openIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.terms.isEmpty) return const SizedBox.shrink();
    final open = _openIndex;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '言葉の意味（タップ）',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < widget.terms.length; i++)
                _TermChip(
                  label: widget.terms[i].term,
                  isOpen: open == i,
                  onTap: () =>
                      setState(() => _openIndex = open == i ? null : i),
                ),
            ],
          ),
          if (open != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                widget.terms[open].meaning,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({
    required this.label,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: isOpen
          ? AppColors.info.withValues(alpha: 0.18)
          : AppColors.surfaceHigh,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // Container に alignment を渡すと幅いっぱいに広がり、
        // Wrap の中で 1 行 1 チップになってしまう。
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isOpen ? AppColors.info : AppColors.border,
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOpen ? Icons.help_rounded : Icons.help_outline_rounded,
                  size: 13,
                  color: isOpen ? AppColors.info : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? AppColors.info : AppColors.textSecondary,
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
