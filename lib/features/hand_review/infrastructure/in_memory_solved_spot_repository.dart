import '../../../shared/models/playing_card.dart';
import '../domain/solved_spot.dart';
import '../domain/solved_spot_repository.dart';

/// メモリ上のリストから検索するだけの実装。
///
/// テスト用のほか、[AssetSolvedSpotRepository] が読み込み後に実際の検索
/// ロジックを委譲する先としても使う。
class InMemorySolvedSpotRepository implements SolvedSpotRepository {
  const InMemorySolvedSpotRepository([this.spots = const []]);

  final List<SolvedSpot> spots;

  @override
  Future<void> ensureLoaded() => Future<void>.value();

  @override
  List<FlopDecisionMatch> firstFlopDecisionMatches({
    required List<PlayingCard> heroHand,
    required List<PlayingCard> flopBoard,
  }) {
    final heroSet = heroHand.toSet();
    final boardSet = flopBoard.toSet();
    if (heroSet.length != 2 || boardSet.length != 3) return const [];

    final matches = <FlopDecisionMatch>[];
    for (final spot in spots) {
      if (!_sameCards(spot.boardFlop, boardSet)) continue;
      for (final entry in spot.entries) {
        if (!_sameCards(entry.heroCombo, heroSet)) continue;
        matches.add(
          FlopDecisionMatch(
            spotId: spot.id,
            villainRangeNotation: spot.villainRangeNotation,
            strategy: entry.strategy,
            iterationsTrained: spot.iterationsTrained,
            measuredExactExploitability: spot.measuredExactExploitability,
          ),
        );
      }
    }
    return matches;
  }

  static bool _sameCards(List<PlayingCard> cards, Set<PlayingCard> target) {
    final set = cards.toSet();
    return set.length == target.length && set.difference(target).isEmpty;
  }
}
