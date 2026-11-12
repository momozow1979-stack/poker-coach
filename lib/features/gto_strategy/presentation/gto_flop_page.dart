import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/playing_card.dart';
import '../../../shared/models/starting_hand.dart';
import '../../../shared/widgets/app_card.dart';
import '../../range_chart/presentation/widgets/range_cell.dart';
import '../application/gto_flop_providers.dart';
import '../domain/gto_flop_strategy.dart';

/// 積極的な行動（ベット／コール＋レイズ）を表す色。
const Color _betColor = Color(0xFF059669);

/// おとなしい行動（チェック／フォールド）を表す色。
const Color _checkColor = Color(0xFF64748B);

const _streetLabels = ['フロップ', 'ターン', 'リバー'];

const _turnBucketLabels = {'blank': 'ブランク', 'over': 'オーバー', 'texture': '変化'};

const _riverBucketLabels = {'blank': 'ブランク', 'scare': 'スケア'};

/// 1つの意思決定ノードの、チップ表示用ラベルと説明文。
class _NodeMeta {
  const _NodeMeta(
    this.chipLabel,
    this.description, {
    this.isRaiseAnchor = false,
  });

  final String chipLabel;
  final String description;

  /// レイズに直面した場面は、`solve_srp_btn_bb.py` が全サイズの組み合わせを
  /// 網羅せず「1/2ポットのベット→1/2ポットのレイズ」という1パターンだけを
  /// 代表例として読み出している（docstring参照）。これを画面上で開示する。
  final bool isRaiseAnchor;
}

/// `solve_srp_btn_bb.py`（`_STREET_NODES`）が実際に読み出した意思決定ノードの
/// 一覧。フロップ・ターン・リバーいずれの街でも同じ12種類が揃っている。
const _nodeOrder = [
  'oop_first',
  'ip_vs_check',
  'ip_vs_bet_1',
  'ip_vs_bet_2',
  'ip_vs_bet_3',
  'ip_vs_bet_4',
  'oop_vs_checkbet_1',
  'oop_vs_checkbet_2',
  'oop_vs_checkbet_3',
  'oop_vs_checkbet_4',
  'oop_vs_raise',
  'ip_vs_raise_after_check',
];

const _nodeMeta = {
  'oop_first': _NodeMeta('OOP 最初の手番', 'チェックするか、ベットするか（OOPの最初の判断）。'),
  'ip_vs_check': _NodeMeta('IP チェック後', 'OOPがチェックした後、IPがチェックするかベットするか。'),
  'ip_vs_bet_1': _NodeMeta(
    'IP vs 1/3ベット',
    'OOPが1/3ポットでベットした後、IPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'ip_vs_bet_2': _NodeMeta(
    'IP vs 1/2ベット',
    'OOPが1/2ポットでベットした後、IPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'ip_vs_bet_3': _NodeMeta(
    'IP vs 2/3ベット',
    'OOPが2/3ポットでベットした後、IPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'ip_vs_bet_4': _NodeMeta(
    'IP vs オーバーベット',
    'OOPがオーバーベット（1.5倍ポット）した後、IPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'oop_vs_checkbet_1': _NodeMeta(
    'OOP vs 1/3（チェック後）',
    'OOPのチェック後、IPが1/3ポットでベットした。OOPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'oop_vs_checkbet_2': _NodeMeta(
    'OOP vs 1/2（チェック後）',
    'OOPのチェック後、IPが1/2ポットでベットした。OOPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'oop_vs_checkbet_3': _NodeMeta(
    'OOP vs 2/3（チェック後）',
    'OOPのチェック後、IPが2/3ポットでベットした。OOPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'oop_vs_checkbet_4': _NodeMeta(
    'OOP vs オーバー（チェック後）',
    'OOPのチェック後、IPがオーバーベットした。OOPがフォールド/コール/レイズのどれを選ぶか。',
  ),
  'oop_vs_raise': _NodeMeta(
    'OOP vs レイズ',
    'OOPが1/2ポットでベットし、IPが1/2ポットでレイズしてきた代表例のみ。'
        '他のベット/レイズサイズの組み合わせは読み出していない。',
    isRaiseAnchor: true,
  ),
  'ip_vs_raise_after_check': _NodeMeta(
    'IP vs レイズ（チェック後）',
    'OOPがチェックし、IPが1/2ポットでベット、OOPが1/2ポットでレイズしてきた代表例のみ。'
        '他のベット/レイズサイズの組み合わせは読み出していない。',
    isRaiseAnchor: true,
  ),
};

/// ソルバーで学習したフロップ以降の戦略ビューア（13×13 ヒートマップ）。
///
/// フロップ／ターン／リバーの各街について、ソルバーが実際に読み出した
/// 意思決定ノード（OOPの最初の手番から、各サイズのベットに直面した応答、
/// レイズに直面した代表例まで）を全て選んで見られる。
class GtoFlopPage extends ConsumerStatefulWidget {
  const GtoFlopPage({super.key});

  @override
  ConsumerState<GtoFlopPage> createState() => _GtoFlopPageState();
}

class _GtoFlopPageState extends ConsumerState<GtoFlopPage> {
  int _selected = 0;
  int _street = 0;
  String? _turnBucket;
  String? _riverBucket;
  String? _nodeKey;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gtoFlopStrategyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GTOフロップ戦略')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const SizedBox.shrink(),
          data: (strategy) {
            if (strategy.spots.isEmpty) return const SizedBox.shrink();
            final index = _selected.clamp(0, strategy.spots.length - 1);
            final spot = strategy.spots[index];

            final turnKeys = spot.turns.keys.toList();
            final turnBucket = turnKeys.isEmpty
                ? null
                : (turnKeys.contains(_turnBucket)
                      ? _turnBucket!
                      : turnKeys.first);
            final riverKeys = turnBucket == null
                ? const <String>[]
                : (spot.rivers[turnBucket]?.keys.toList() ?? const []);
            final riverBucket = riverKeys.isEmpty
                ? null
                : (riverKeys.contains(_riverBucket)
                      ? _riverBucket!
                      : riverKeys.first);

            final displayedBoard = [...spot.board];
            final Map<String, GtoActionNode> currentNodes;
            if (_street == 0) {
              currentNodes = spot.nodes;
            } else {
              final turnNode = turnBucket == null
                  ? null
                  : spot.turns[turnBucket];
              if (turnNode != null) displayedBoard.add(turnNode.card);
              if (_street == 1 || turnNode == null) {
                currentNodes = turnNode?.nodes ?? const {};
              } else {
                final riverNode = riverBucket == null
                    ? null
                    : spot.rivers[turnBucket]?[riverBucket];
                if (riverNode != null) displayedBoard.add(riverNode.card);
                currentNodes = riverNode?.nodes ?? const {};
              }
            }

            final nodeKeys = _nodeOrder
                .where(currentNodes.containsKey)
                .toList();
            final nodeKey = nodeKeys.isEmpty
                ? null
                : (nodeKeys.contains(_nodeKey) ? _nodeKey! : nodeKeys.first);
            final currentNode = nodeKey == null ? null : currentNodes[nodeKey];

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _boardSelector(strategy, index),
                const SizedBox(height: AppSpacing.md),
                _streetTabs(),
                if (_street >= 1 && turnKeys.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _turnBucketSelector(spot, turnKeys, turnBucket!),
                ],
                if (_street == 2 && riverKeys.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _riverBucketSelector(
                    spot,
                    turnBucket!,
                    riverKeys,
                    riverBucket!,
                  ),
                ],
                if (_street >= 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _streetDisclosure(),
                ],
                if (nodeKeys.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _nodeSelector(nodeKeys, nodeKey!),
                  const SizedBox(height: AppSpacing.sm),
                  _nodeDescription(nodeKey),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text(
                      'ボード',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _boardLabel(displayedBoard, onDark: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AspectRatio(aspectRatio: 1, child: _grid(currentNode)),
                const SizedBox(height: AppSpacing.lg),
                _legend(currentNode),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _boardSelector(GtoFlopStrategy strategy, int selected) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: strategy.spots.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final isSel = i == selected;
          return GestureDetector(
            onTap: () => setState(() {
              _selected = i;
              _street = 0;
              _turnBucket = null;
              _riverBucket = null;
              _nodeKey = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSel ? AppColors.accent : AppColors.border,
                ),
              ),
              child: _boardLabel(strategy.spots[i].board, onDark: isSel),
            ),
          );
        },
      ),
    );
  }

  Widget _streetTabs() {
    return Row(
      children: [
        for (var i = 0; i < _streetLabels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _street = i;
                _nodeKey = null;
                if (i == 0) {
                  _turnBucket = null;
                  _riverBucket = null;
                } else if (i == 1) {
                  _riverBucket = null;
                }
              }),
              child: Container(
                margin: EdgeInsets.only(
                  right: i < _streetLabels.length - 1 ? AppSpacing.sm : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _street == i ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _street == i ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  _streetLabels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _street == i ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _turnBucketSelector(
    GtoFlopSpot spot,
    List<String> keys,
    String selected,
  ) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final key = keys[i];
          final node = spot.turns[key]!;
          final isSel = key == selected;
          return GestureDetector(
            onTap: () => setState(() {
              _turnBucket = key;
              _riverBucket = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSel ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                '${_turnBucketLabels[key] ?? key} ${node.card.display}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _riverBucketSelector(
    GtoFlopSpot spot,
    String turnBucket,
    List<String> keys,
    String selected,
  ) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final key = keys[i];
          final node = spot.rivers[turnBucket]![key]!;
          final isSel = key == selected;
          return GestureDetector(
            onTap: () => setState(() => _riverBucket = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSel ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                '${_riverBucketLabels[key] ?? key} ${node.card.display}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _streetDisclosure() {
    final through = _street == 2 ? 'フロップ・ターン' : 'フロップ';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$throughでチェックが続いた場合の戦略です。代表的なカード1枚だけを'
        '抜き出した近似のため、実際に起こりうる全てのカードを網羅してはいません。',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _nodeSelector(List<String> keys, String selected) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in keys)
          GestureDetector(
            onTap: () => setState(() => _nodeKey = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: key == selected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: key == selected ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                _nodeMeta[key]?.chipLabel ?? key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: key == selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _nodeDescription(String nodeKey) {
    final meta = _nodeMeta[nodeKey];
    if (meta == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: meta.isRaiseAnchor
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        meta.description,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _boardLabel(List<PlayingCard> board, {required bool onDark}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final card in board)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              '${card.rank.symbol}${card.suit.symbol}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: onDark
                    ? Colors.white
                    : (card.suit.isRed
                          ? AppColors.danger
                          : AppColors.textPrimary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(GtoActionNode? node) {
    return Column(
      children: [
        for (var row = 0; row < 13; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 13; col++)
                  Expanded(child: _cell(StartingHand.fromGrid(row, col), node)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(StartingHand hand, GtoActionNode? node) {
    final aggression = node?.aggressionFor(hand.code);
    final Color bg;
    if (aggression == null) {
      bg = AppColors.rangeFold;
    } else {
      bg = Color.lerp(_checkColor, _betColor, aggression)!;
    }
    return RangeCell(
      code: hand.code,
      topColor: bg,
      bottomColor: bg,
      textColor: aggression == null ? AppColors.textMuted : Colors.white,
      onTap: aggression == null ? null : () => _showDetail(hand, node!),
    );
  }

  void _showDetail(StartingHand hand, GtoActionNode node) {
    final row = node.actionsFor(hand.code);
    if (row == null) return;
    final isBetType = node.passiveAction == 'x';
    final order = isBetType
        ? const ['x', '1', '2', '3', '4']
        : const ['f', 'c', '1', '2', '3', '4'];
    final sizeWord = isBetType ? 'ベット' : 'レイズ';
    final entries = [
      for (final key in order)
        if (row.containsKey(key)) MapEntry(key, row[key]!),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hand.code}（${hand.description}）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final entry in entries) ...[
              _bar(
                _actionLabel(entry.key, sizeWord),
                (entry.value * 100).round(),
                entry.key == node.passiveAction ? _checkColor : _betColor,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  String _actionLabel(String key, String sizeWord) {
    switch (key) {
      case 'x':
        return 'チェック';
      case 'f':
        return 'フォールド';
      case 'c':
        return 'コール';
      case '1':
        return '$sizeWord 1/3';
      case '2':
        return '$sizeWord 1/2';
      case '3':
        return '$sizeWord 2/3';
      case '4':
        return '$sizeWordオーバー';
      default:
        return key;
    }
  }

  Widget _bar(String label, int pct, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 14,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(GtoActionNode? node) {
    final isBetType = (node?.passiveAction ?? 'x') == 'x';
    final passiveLabel = isBetType ? 'チェック' : 'フォールド';
    final activeLabel = isBetType ? 'ベット' : 'コール＋レイズ';
    return AppCard(
      child: Row(
        children: [
          Text(
            passiveLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [_checkColor, _betColor],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            activeLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
