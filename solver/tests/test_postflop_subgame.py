"""PostflopSubgame tests.

Training this game even one iteration is far too slow for CI (measured
~31.5s/iteration on the smallest possible range — see BENCHMARKS.md) — the
whole point of this module right now is that full-tree Python CFR cannot
handle a real, connected flop-turn-river tree, not that it can be trained
quickly. So this test only checks the game's structure is correct
(well-formed, correct combo/board bookkeeping across streets), not
convergence.
"""

from __future__ import annotations

from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card
from tests.test_game_interface import assert_game_is_well_formed


def _flop_board() -> list[int]:
    # Deliberately avoids A and K entirely, so neither AA nor KK can ever
    # improve to a set on any runout — keeps "AA always beats KK" true
    # regardless of which turn/river cards land.
    return [parse_card(c) for c in ("7h", "2d", "3s")]


def test_postflop_subgame_is_well_formed() -> None:
    # The smallest possible range on each side: AA and KK, neither touched
    # by this board (6 combos each).
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    assert_game_is_well_formed(game, max_histories=10_000_000)


def test_combo_counts_match_pair_combinatorics() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    assert len(game.hero_combos) == 6
    assert len(game.villain_combos) == 6


def test_wider_range_combo_counts_match_measured_values() -> None:
    """Doesn't build/walk the tree (see BENCHMARKS.md — these ranges are far
    too large to train or well-formedness-check in CI) — just pins the
    combo expansion itself, the cheap part, against the counts actually
    measured when scaling `PostflopSubgame` past the `AA` vs `KK` toy case.
    """
    board = _flop_board()
    for hero_r, villain_r, expected_hero, expected_villain in [
        ("QQ+", "TT-JJ", 18, 12),
        ("TT+", "22-99", 30, 39),
        ("22+", "22+", 69, 69),
    ]:
        game = PostflopSubgame(board, hero_range_notation=hero_r, villain_range_notation=villain_r)
        assert len(game.hero_combos) == expected_hero, hero_r
        assert len(game.villain_combos) == expected_villain, villain_r


def test_showdown_uses_the_full_five_card_board() -> None:
    # AA vs KK on a board that never pairs either: aces stay ahead through
    # the river regardless of which two extra cards land, so hero's equity
    # against every villain combo, on every possible complete board, is 1.0.
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    board5 = game.flop_board + (parse_card("4c"), parse_card("9d"))
    for hero_combo in game.hero_combos:
        for villain_combo in game.villain_combos:
            if set(hero_combo) & set(villain_combo):
                continue
            assert game._equity(hero_combo, villain_combo, board5) == 1.0
