"""FlopSubgame tests.

Keeps the CI-committed test on a deliberately tiny range (single hand code
per side) so it runs in seconds — the real, wider "pairs only" pilot
benchmark used to evaluate the Phase 2 performance gate is documented in
`BENCHMARKS.md` instead of committed as a test (5,000 iterations took
about 10 minutes on the measuring machine, far too slow for routine CI).
"""

from __future__ import annotations

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import exploitability
from cfr_solver.games.flop_subgame import FlopSubgame
from cfr_solver.poker.cards import parse_card
from tests.test_game_interface import assert_game_is_well_formed


def _tiny_board() -> list[int]:
    # A rainbow board that doesn't interact with AA or KK at all (no pairing,
    # no straight/flush relevance) so the showdown is a clean "AA beats KK".
    return [parse_card(c) for c in ("7h", "2d", "3c")]


def test_flop_subgame_is_well_formed() -> None:
    game = FlopSubgame(_tiny_board(), hero_range_notation="AA", villain_range_notation="KK")
    assert_game_is_well_formed(game, max_histories=50_000)


def test_hero_combo_count_matches_pair_combinatorics() -> None:
    # A pair has 4 physical cards -> C(4,2) = 6 combos, and this board
    # doesn't touch aces or kings, so nothing should be removed.
    game = FlopSubgame(_tiny_board(), hero_range_notation="AA", villain_range_notation="KK")
    assert len(game.hero_combos) == 6
    assert len(game.villain_combos) == 6


def test_board_removal_shrinks_combo_count() -> None:
    # The board holds one 7 (7h), so hero's own pair ("77") only has 3 of
    # its 4 physical sevens left -> C(3,2) = 3 combos instead of 6.
    game = FlopSubgame(_tiny_board(), hero_range_notation="77", villain_range_notation="KK")
    assert len(game.hero_combos) == 3


def test_pocket_aces_beats_pocket_kings_on_a_blank_board() -> None:
    game = FlopSubgame(_tiny_board(), hero_range_notation="AA", villain_range_notation="KK")
    for hero_combo in game.hero_combos:
        for villain_combo in game.villain_combos:
            assert game._equity(hero_combo, villain_combo) == 1.0


def test_exploitability_decreases_with_more_training() -> None:
    game = FlopSubgame(_tiny_board(), hero_range_notation="AA", villain_range_notation="KK")
    solver = CFRSolver(game, variant="cfr_plus")

    solver.train(50)
    exploit_low = exploitability(game, solver.average_strategy())

    solver.train(450)
    exploit_high = exploitability(game, solver.average_strategy())

    assert exploit_high < exploit_low
