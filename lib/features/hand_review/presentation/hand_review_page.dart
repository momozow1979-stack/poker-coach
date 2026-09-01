import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/poker_action.dart';
import '../../../shared/models/street.dart';
import '../../../shared/models/table_type.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../profile/application/learning_providers.dart';
import '../application/hand_review_providers.dart';
import '../domain/hand_flow.dart';
import '../domain/hand_review_input.dart';
import 'widgets/action_prompt_card.dart';
import 'widgets/card_picker_sheet.dart';
import 'widgets/card_slot_row.dart';
import 'widgets/form_section.dart';
import 'widgets/hand_timeline.dart';
import 'widgets/position_picker.dart';

/// ハンドレビューの入力画面。
///
/// ポジションが決まれば行動順は決まるので、「誰の番か」は選ばせない。
/// ストリートが終われば自動で次のカード入力へ進む。
/// 額は分からなければ飛ばせる。
class HandReviewPage extends ConsumerWidget {
  const HandReviewPage({super.key});

  /// 有効スタックの候補。先頭は「分からない」。
  static const _stackPresets = <double?>[null, 30, 50, 75, 100, 150, 200];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(handReviewFormProvider);
    final form = ref.read(handReviewFormProvider.notifier);
    final flow = ref.watch(handReviewFlowProvider);
    final submission = ref.watch(handReviewControllerProvider);
    final history = ref.watch(handReviewHistoryProvider);

    ref.listen(handReviewControllerProvider, (previous, next) {
      if (next.value != null) {
        context.go(AppRoutes.reviewResult);
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レビューの生成に失敗しました。もう一度お試しください。')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ハンドを入力'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.review),
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: '履歴',
              onPressed: () => _showHistory(context, ref),
              icon: const Icon(Icons.history_rounded),
            ),
          IconButton(
            tooltip: '入力をクリア',
            onPressed: form.reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            FormSection(
              title: '卓と席',
              subtitle: '席をタップして、自分と相手を選びます',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChoiceChipGroup<TableType>(
                    values: TableType.values,
                    selected: input.tableType,
                    labelBuilder: (value) => value.label,
                    onSelected: form.setTableType,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PositionPicker(
                    tableType: input.tableType,
                    heroPosition: input.heroPosition,
                    villainPosition: input.villainPosition,
                    onHeroChanged: form.setHeroPosition,
                    onVillainChanged: form.setVillainPosition,
                  ),
                ],
              ),
            ),
            FormSection(
              title: '有効スタック',
              subtitle: '分からなければ「分からない」で構いません',
              child: ChoiceChipGroup<double?>(
                values: _stackPresets,
                selected: input.effectiveStackBb,
                labelBuilder: (value) =>
                    value == null ? '分からない' : '${value.toInt()}BB',
                onSelected: form.setEffectiveStack,
              ),
            ),
            FormSection(
              title: 'あなたのハンド',
              child: CardSlotRow(
                cards: input.heroHand,
                slotCount: 2,
                onTap: () => _pickCards(
                  context: context,
                  ref: ref,
                  title: 'あなたのハンドを選択',
                  maxCount: 2,
                  current: input.heroHand,
                  onSelected: form.setHeroHand,
                ),
              ),
            ),
            FormSection(
              title: '相手のハンド（任意）',
              subtitle: 'ショーダウンで見えたときだけ。入れると勝率まで出せます',
              child: CardSlotRow(
                cards: input.villainHand,
                slotCount: 2,
                onTap: () => _pickCards(
                  context: context,
                  ref: ref,
                  title: '相手のハンドを選択',
                  maxCount: 2,
                  current: input.villainHand,
                  onSelected: form.setVillainHand,
                ),
              ),
            ),
            FormSection(
              title: '相手の特徴（任意）',
              subtitle: '実戦調整のコメントが変わります',
              child: ChoiceChipGroup<VillainProfile>(
                values: VillainProfile.values,
                selected: input.villainProfile,
                labelBuilder: (value) => value.label,
                onSelected: form.setVillainProfile,
              ),
            ),
            FormSection(
              title: 'ハンドの流れ',
              subtitle: '誰の番かは席から決まります。順に選ぶだけで進みます',
              child: HandTimeline(
                input: input,
                villainLabel: input.villainPosition.label,
                onUndo: form.canUndo ? form.undoLast : null,
              ),
            ),
            _CurrentStep(
              flow: flow,
              input: input,
              onPickBoard: (street, count) => _pickCards(
                context: context,
                ref: ref,
                title: '${street.label}のカードを選択',
                maxCount: count,
                current: input.boardOf(street),
                onSelected: (cards) => form.setStreetCards(street, cards),
              ),
              onAddAction: (action, sizeBb) => form.addAction(
                flow.step is NeedAction
                    ? (flow.step as NeedAction).prompt.street
                    : Street.preflop,
                HandAction(
                  actor: flow.nextActorKey,
                  action: action,
                  sizeBb: sizeBb,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FormSection(
              title: '迷ったポイント（任意）',
              subtitle: '入力しなくてもレビューできます',
              child: TextField(
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '例）ターンでベットサイズを大きくしすぎた気がする',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onChanged: form.setUserQuestion,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: flow.isReady && !submission.isLoading
                  ? ref.read(handReviewControllerProvider.notifier).submit
                  : null,
              icon: submission.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(submission.isLoading ? '分析中…' : 'レビューを実行'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCards({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required int maxCount,
    required List<PlayingCard> current,
    required ValueChanged<List<PlayingCard>> onSelected,
  }) async {
    final input = ref.read(handReviewFormProvider);
    final used = {...input.usedCards}..removeAll(current);
    final selection = await showCardPicker(
      context,
      title: title,
      maxCount: maxCount,
      initialSelection: current,
      disabledCards: used,
    );
    if (selection != null) onSelected(selection);
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final history = ref.read(handReviewHistoryProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'レビュー履歴',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final record in history)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${record.score} / 100',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        record.result.summary,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// いま入力すべきものだけを出す。
class _CurrentStep extends StatelessWidget {
  const _CurrentStep({
    required this.flow,
    required this.input,
    required this.onPickBoard,
    required this.onAddAction,
  });

  final HandFlow flow;
  final HandReviewInput input;
  final void Function(Street street, int count) onPickBoard;
  final void Function(PokerActionType action, double? sizeBb) onAddAction;

  @override
  Widget build(BuildContext context) {
    return switch (flow.step) {
      NeedHeroHand() => const _Hint(
        icon: Icons.style_outlined,
        text: 'まず、あなたのハンド2枚を選んでください。',
      ),
      NeedBoard(:final street, :final count) => AppCard(
        borderColor: AppColors.warning.withValues(alpha: 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${street.label}の$count枚を入れてください',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CardSlotRow(
              cards: input.boardOf(street),
              slotCount: count,
              onTap: () => onPickBoard(street, count),
            ),
          ],
        ),
      ),
      NeedAction(:final prompt) => ActionPromptCard(
        prompt: prompt,
        onAdd: onAddAction,
      ),
      ReviewReady(:final endedByFold, :final foldedBy) => _Hint(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.accent,
        text: endedByFold
            ? '${foldedBy == Actor.hero ? 'あなた' : '相手'}がフォールドして'
                  'ハンドが終わりました。このままレビューできます。'
            : 'ショーダウンまで進みました。このままレビューできます。',
      ),
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceHigh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.7, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
