import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/range_providers.dart';
import '../domain/range_action.dart';
import '../domain/range_entry.dart';

/// レンジ表暗記ドリル（目隠し）。
///
/// 表を隠した状態でハンドを1つずつ出し、正しいアクションを当てる。
/// 正解は現在選択中のレンジ表（[selectedRangeChartProvider]）から引く。
/// Mixed（複数アクションを混ぜる手）は正解が一つに定まらないので当面は出題しない。
class RangeDrillPage extends ConsumerStatefulWidget {
  const RangeDrillPage({super.key});

  @override
  ConsumerState<RangeDrillPage> createState() => _RangeDrillPageState();
}

class _RangeDrillPageState extends ConsumerState<RangeDrillPage> {
  static const _order = [
    RangeAction.raise,
    RangeAction.threeBet,
    RangeAction.fourBet,
    RangeAction.call,
    RangeAction.fold,
  ];

  String? _builtForSpotId;
  List<StartingHand> _queue = [];
  List<RangeAction> _choices = [];
  int _index = 0;
  int _correct = 0;
  RangeAction? _answer;

  bool get _finished => _queue.isNotEmpty && _index >= _queue.length;

  void _build(RangeChart chart) {
    final nonMixed = StartingHand.all
        .where((h) => chart.entryFor(h).action != RangeAction.mixed)
        .toList();
    final inRange =
        nonMixed
            .where((h) => chart.entryFor(h).action != RangeAction.fold)
            .toList()
          ..shuffle();
    final folds =
        nonMixed
            .where((h) => chart.entryFor(h).action == RangeAction.fold)
            .toList()
          ..shuffle();
    // レンジ（プレイするハンド）を中心に、境目を学べるようフォールドも少し混ぜる。
    _queue = <StartingHand>[...inRange.take(16), ...folds.take(8)]..shuffle();

    final present = <RangeAction>{
      for (final h in inRange) chart.entryFor(h).action,
    };
    _choices = [
      for (final a in _order)
        if (a == RangeAction.fold || present.contains(a)) a,
    ];

    _index = 0;
    _correct = 0;
    _answer = null;
    _builtForSpotId = chart.spot.id;
  }

  void _select(RangeAction action, RangeChart chart) {
    if (_answer != null) return;
    setState(() {
      _answer = action;
      if (action == chart.entryFor(_queue[_index]).action) _correct++;
    });
  }

  void _next() => setState(() {
    _index++;
    _answer = null;
  });

  @override
  Widget build(BuildContext context) {
    final chart = ref.watch(selectedRangeChartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('レンジ表暗記')),
      body: SafeArea(
        child: chart == null
            ? const Center(child: Text('レンジ表を選んでください。'))
            : _buildBody(chart),
      ),
    );
  }

  Widget _buildBody(RangeChart chart) {
    if (_builtForSpotId != chart.spot.id) _build(chart);
    if (_queue.isEmpty) {
      return const Center(child: Text('このスポットには出題できるハンドがありません。'));
    }
    if (_finished) return _buildSummary(chart);

    final hand = _queue[_index];
    final correctAction = chart.entryFor(hand).action;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chart.spot.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_index + 1} / ${_queue.length}・正解 $_correct',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    hand.code,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hand.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'このハンドのアクションは？',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final action in _choices) ...[
            _ChoiceButton(
              action: action,
              answered: _answer != null,
              isCorrect: action == correctAction,
              isSelected: action == _answer,
              onTap: () => _select(action, chart),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const Spacer(),
          if (_answer != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                child: Text(_index + 1 >= _queue.length ? '結果を見る' : '次のハンド'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(RangeChart chart) {
    final total = _queue.length;
    final pct = total == 0 ? 0 : (_correct / total * 100).round();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$total問中 $_correct問正解',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '正答率 $pct%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => setState(() => _build(chart)),
            child: const Text('もう一度'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.action,
    required this.answered,
    required this.isCorrect,
    required this.isSelected,
    required this.onTap,
  });

  final RangeAction action;
  final bool answered;
  final bool isCorrect;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 未回答は淡い枠、回答後は正解を強調・誤選択を赤枠で示す。
    Color border = AppColors.border;
    Color bg = AppColors.surface;
    if (answered) {
      if (isCorrect) {
        border = action.color;
        bg = action.color.withValues(alpha: 0.14);
      } else if (isSelected) {
        border = AppColors.danger;
        bg = AppColors.danger.withValues(alpha: 0.10);
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: answered ? 2 : 1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: action == RangeAction.fold
                      ? AppColors.rangeFold
                      : action.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  action.symbol,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: action == RangeAction.fold
                        ? AppColors.textMuted
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (answered && isCorrect)
                Icon(Icons.check_circle, color: action.color, size: 20),
              if (answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: AppColors.danger, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
