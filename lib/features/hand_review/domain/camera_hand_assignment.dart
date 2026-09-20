import '../../../shared/models/playing_card.dart';
import 'hand_review_input.dart';
import 'read_hand_result.dart';

/// 確認画面で1枚に割り当てる役割。ユーザーがプルダウンで選び直せる。
enum HandSlot {
  hero('自分'),
  flop('フロップ'),
  turn('ターン'),
  river('リバー'),
  villain('相手'),
  exclude('除外');

  const HandSlot(this.label);

  final String label;
}

/// 確認画面で扱う、役割つきの1枚（可変）。
class AssignedCard {
  AssignedCard({
    required this.card,
    required this.confidence,
    required this.slot,
    this.villainIndex = 1,
  });

  final PlayingCard card;
  final double confidence;
  HandSlot slot;

  /// 相手の何人目か（1 から）。[slot] が villain のときだけ意味を持つ。
  int villainIndex;
}

/// 読み取り結果から、確認画面の初期割り当てを作る。
///
/// - 自分(me) → hero
/// - 場(board) → board_order 昇順で 先頭3=フロップ / 4枚目=ターン / 5枚目=リバー
///   （降りて5枚に満たない場合も、ある分だけ割り当てる。6枚以上は除外）
/// - 相手(villain) → villain（cluster を人番号に）
List<AssignedCard> initialAssignments(ReadHandResult result) {
  final assigned = <AssignedCard>[];

  final board =
      result.cards.where((c) => c.suggested == ReadCardRole.board).toList()
        ..sort(
          (a, b) =>
              (a.boardOrder ?? 1 << 30).compareTo(b.boardOrder ?? 1 << 30),
        );
  const boardSlots = [
    HandSlot.flop,
    HandSlot.flop,
    HandSlot.flop,
    HandSlot.turn,
    HandSlot.river,
  ];
  for (var i = 0; i < board.length; i++) {
    assigned.add(
      AssignedCard(
        card: board[i].card,
        confidence: board[i].confidence,
        slot: i < boardSlots.length ? boardSlots[i] : HandSlot.exclude,
      ),
    );
  }

  for (final c in result.cards.where((c) => c.suggested == ReadCardRole.me)) {
    assigned.add(
      AssignedCard(card: c.card, confidence: c.confidence, slot: HandSlot.hero),
    );
  }

  for (final c in result.cards.where(
    (c) => c.suggested == ReadCardRole.villain,
  )) {
    assigned.add(
      AssignedCard(
        card: c.card,
        confidence: c.confidence,
        slot: HandSlot.villain,
        villainIndex: c.cluster ?? 1,
      ),
    );
  }

  return assigned;
}

/// 割り当てを既存の [HandReviewInput] に反映する（純粋関数）。
///
/// 現行のレビューはヘッズアップ前提（相手の手は1つ）なので、相手が複数写って
/// いても、レビューに使うのは [reviewVillainIndex]（既定は最小の人番号）の2枚だけ。
/// 場は開いている枚数だけ入る（フロップのみ/ターンまで/リバーまで）。
HandReviewInput applyAssignments(
  HandReviewInput base,
  List<AssignedCard> cards, {
  int? reviewVillainIndex,
}) {
  List<PlayingCard> of(HandSlot slot, int take) =>
      cards.where((c) => c.slot == slot).map((c) => c.card).take(take).toList();

  final villains = cards.where((c) => c.slot == HandSlot.villain).toList();
  final targetIndex =
      reviewVillainIndex ??
      (villains.isEmpty
          ? 1
          : villains
                .map((c) => c.villainIndex)
                .reduce((a, b) => a < b ? a : b));
  final villainHand = villains
      .where((c) => c.villainIndex == targetIndex)
      .map((c) => c.card)
      .take(2)
      .toList();

  return base.copyWith(
    heroHand: of(HandSlot.hero, 2),
    villainHand: villainHand,
    flop: base.flop.copyWith(cards: of(HandSlot.flop, 3)),
    turn: base.turn.copyWith(cards: of(HandSlot.turn, 1)),
    river: base.river.copyWith(cards: of(HandSlot.river, 1)),
  );
}

/// 枚数が想定どおりか（確認画面の注意表示に使う）。
/// 自分=2 / フロップ=3 / ターン≤1 / リバー≤1(ターンがある時のみ) / 各相手=2。
bool hasSlotWarning(List<AssignedCard> cards) {
  int count(HandSlot s) => cards.where((c) => c.slot == s).length;
  final flop = count(HandSlot.flop);
  final turn = count(HandSlot.turn);
  final river = count(HandSlot.river);
  if (count(HandSlot.hero) != 2) return true;
  if (flop != 0 && flop != 3) return true;
  if (turn > 1) return true;
  if (river > 1) return true;
  if (river == 1 && turn == 0) return true; // リバーがあるのにターンが無い
  // 相手は人ごとに2枚。
  final byIndex = <int, int>{};
  for (final c in cards.where((c) => c.slot == HandSlot.villain)) {
    byIndex[c.villainIndex] = (byIndex[c.villainIndex] ?? 0) + 1;
  }
  return byIndex.values.any((n) => n != 2);
}
