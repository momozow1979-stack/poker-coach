import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/playing_card_view.dart';
import '../../../shared/widgets/poker_table_view.dart';
import '../../hand_review/domain/hand_flow.dart' show Actor;
import '../domain/practice_event.dart';
import '../domain/practice_hand_record.dart';
import '../domain/practice_hand_state.dart';

/// 保存済みの1ハンドを、イベントを1つずつ進めながら見返す画面。
///
/// ライブプレイと同じ [PracticeHandState.replay] を使うので、
/// 表示のロジックが二重にならず、食い違う心配がない。
class PracticeReplayPage extends StatefulWidget {
  const PracticeReplayPage({super.key, required this.record});

  final PracticeHandRecord record;

  @override
  State<PracticeReplayPage> createState() => _PracticeReplayPageState();
}

class _PracticeReplayPageState extends State<PracticeReplayPage> {
  /// いま何個目までのイベントを反映しているか（最低 1 = HandDealt のみ）。
  int _cursor = 1;

  @override
  Widget build(BuildContext context) {
    final events = widget.record.events;
    final visible = events.sublist(0, _cursor);
    final hand = PracticeHandState.replay(visible);
    final lastEvent = events[_cursor - 1];

    return Scaffold(
      appBar: AppBar(title: const Text('リプレイ')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    PokerTableView(
                      tableType: hand.tableType,
                      heroPosition: hand.heroPosition,
                      villainPosition: hand.villainPosition,
                      potLabel: 'Pot ${hand.pot}BB',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        for (final card in hand.villainCards)
                          PlayingCardView(
                            card: hand.sawShowdown ? card : null,
                            width: 36,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        for (final card in hand.board)
                          PlayingCardView(card: card, width: 36),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        for (final card in hand.heroCards)
                          PlayingCardView(card: card, width: 36),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _describe(lastEvent),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _cursor > 1
                        ? () => setState(() => _cursor--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('$_cursor / ${events.length}'),
                  IconButton(
                    onPressed: _cursor < events.length
                        ? () => setState(() => _cursor++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(PracticeEvent event) {
    return switch (event) {
      HandDealt() => 'ハンド開始',
      BoardDealt(:final street) => '${street.label}が開いた',
      ActionOccurred(:final actor, :final action, :final sizeBb) =>
        '${actor == Actor.hero ? 'あなた' : '相手'} ${action.description}'
            '${sizeBb == null ? '' : ' ${sizeBb}BB'}',
      HandFinished(:final endedByFold, :final winner) =>
        endedByFold
            ? '${winner == Actor.hero ? '相手' : 'あなた'}がフォールド'
            : (winner == null
                  ? 'ショーダウン: 分け'
                  : 'ショーダウン: ${winner == Actor.hero ? 'あなた' : '相手'}の勝ち'),
    };
  }
}
