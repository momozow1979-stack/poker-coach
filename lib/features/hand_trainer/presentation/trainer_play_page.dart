import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/collapsible_section.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../application/trainer_providers.dart';
import '../domain/trainer_scenario.dart';
import '../domain/trainer_session.dart';
import 'widgets/pot_odds_tile.dart';
import 'widgets/term_note_card.dart';
import 'widgets/trainer_feedback_card.dart';
import 'widgets/trainer_format.dart';
import 'widgets/trainer_option_button.dart';
import 'widgets/trainer_stage_card.dart';
import 'widgets/trainer_summary_view.dart';

/// 1 ハンドを、プリフロップからリバーまで順に判断していく画面。
///
/// 選んだ直後にその場で解説を出す。
/// 最後にまとめて見せると、どの判断への評価なのかが結びつかないため。
class TrainerPlayPage extends ConsumerStatefulWidget {
  const TrainerPlayPage({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  ConsumerState<TrainerPlayPage> createState() => _TrainerPlayPageState();
}

class _TrainerPlayPageState extends ConsumerState<TrainerPlayPage> {
  @override
  void initState() {
    super.initState();
    // 一覧から入ってきた場合も、URL 直打ちで開かれた場合もここで始める。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(trainerSessionProvider.notifier).start(widget.scenarioId);
      }
    });
  }

  void _backToList() {
    ref.read(trainerSessionProvider.notifier).clear();
    context.go(AppRoutes.trainer);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trainerSessionProvider);

    if (session == null || session.scenario.id != widget.scenarioId) {
      return Scaffold(
        appBar: AppBar(title: const Text('意思決定トレーナー')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.sports_esports_outlined,
            title: 'ハンドを読み込んでいます',
            message: '表示が変わらない場合は、一覧から選び直してください。',
            action: OutlinedButton(
              onPressed: _backToList,
              child: const Text('一覧へ戻る'),
            ),
          ),
        ),
      );
    }

    final scenario = session.scenario;
    final spot = session.currentSpot;

    return Scaffold(
      appBar: AppBar(
        title: Text(scenario.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '一覧へ戻る',
          onPressed: _backToList,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StatusBar(session: session),
        ),
      ),
      body: SafeArea(
        top: false,
        child: spot == null
            ? TrainerSummaryView(
                session: session,
                onRestart: ref.read(trainerSessionProvider.notifier).restart,
                onBackToList: _backToList,
              )
            : _SpotView(
                key: ValueKey('${scenario.id}-${session.spotIndex}'),
                session: session,
                spot: spot,
                onAnswer: ref.read(trainerSessionProvider.notifier).answer,
                onNext: ref.read(trainerSessionProvider.notifier).next,
              ),
      ),
    );
  }
}

/// ポット・スタック・ストリートを常に見えるところに置く。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.session});

  final TrainerSession session;

  @override
  Widget build(BuildContext context) {
    // 総括のときは最後の設問の数字をそのまま残す。
    final spot = session.currentSpot ?? session.scenario.spots.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatusPill(
                icon: Icons.layers_rounded,
                label: session.isFinished ? '総括' : spot.street.label,
                accent: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(
                icon: Icons.savings_rounded,
                label: 'ポット ${formatBb(spot.potBb)}BB',
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(
                icon: Icons.account_balance_wallet_rounded,
                label: 'スタック ${formatBb(spot.stackBb)}BB',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: session.isFinished ? 1 : session.progress,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.accent = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 ストリート分の設問と、回答後の解説。
class _SpotView extends StatefulWidget {
  const _SpotView({
    super.key,
    required this.session,
    required this.spot,
    required this.onAnswer,
    required this.onNext,
  });

  final TrainerSession session;
  final TrainerSpot spot;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;

  @override
  State<_SpotView> createState() => _SpotViewState();
}

class _SpotViewState extends State<_SpotView> {
  /// 回答後に出す解説の位置。選んだ直後にここまで自動で送る。
  final _feedbackKey = GlobalKey();

  @override
  void didUpdateWidget(_SpotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justAnswered =
        oldWidget.session.revealedOptionId == null &&
        widget.session.revealedOptionId != null;
    if (justAnswered) _scrollToFeedback();
  }

  /// 選択肢は画面の下のほうにあるため、解説は初期状態では画面外に出る。
  /// 自分で下げてもらう前提にすると「解説が出ない」と受け取られるので、
  /// 回答した瞬間にこちらから送る。
  void _scrollToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _feedbackKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final spot = widget.spot;
    final onAnswer = widget.onAnswer;
    final onNext = widget.onNext;
    final revealedId = session.revealedOptionId;
    final selected = revealedId == null ? null : spot.optionById(revealedId);
    final isLastSpot = session.spotIndex == session.scenario.spotCount - 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        TrainerStageCard(
          scenario: session.scenario,
          spot: spot,
          board: session.scenario.boardUpTo(spot.street),
        ),
        if (spot.toCallBb > 0) ...[
          const SizedBox(height: AppSpacing.md),
          PotOddsTile(spot: spot),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          spot.question,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
        if (spot.terms.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          TermNoteCard(terms: spot.terms),
        ],
        if (spot.hint != null && selected == null) ...[
          const SizedBox(height: AppSpacing.md),
          CollapsibleSection(
            icon: Icons.tips_and_updates_outlined,
            title: 'ヒントを見る（答えは書いていません）',
            body: spot.hint!,
            accent: AppColors.warning,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < spot.options.length; i++)
          FadeSlideIn(
            key: ValueKey(spot.options[i].id),
            delay: Duration(milliseconds: 60 * i),
            child: TrainerOptionButton(
              option: spot.options[i],
              isRevealed: selected != null,
              isSelected: spot.options[i].id == revealedId,
              onTap: () => onAnswer(spot.options[i].id),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.sm),
          KeyedSubtree(
            key: _feedbackKey,
            child: TrainerFeedbackCard(spot: spot, selected: selected),
          ),
          if (spot.outcome != null && !selected.endsHand) ...[
            const SizedBox(height: AppSpacing.md),
            _OutcomeCard(
              text: spot.outcome!,
              bestLabel: selected.verdict == TrainerVerdict.best
                  ? null
                  : spot.options
                        .where((o) => o.verdict == TrainerVerdict.best)
                        .firstOrNull
                        ?.label,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onNext,
            icon: Icon(
              selected.endsHand || isLastSpot
                  ? Icons.flag_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(selected.endsHand || isLastSpot ? '総括を見る' : '次のストリートへ'),
          ),
        ],
      ],
    );
  }
}

/// 回答後、次のストリートまでに何が起きたか。
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.text, this.bestLabel});

  final String text;

  /// 最善以外を選んだときに、この先どう進むかを断っておくための表示。
  /// null なら最善を選べている。
  final String? bestLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (bestLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '※ 続きを学べるように、この先は最善の「$bestLabel」を選んだものとして進みます。',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
