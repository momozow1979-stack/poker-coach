"""3-player Kuhn Poker convergence test — verification benchmark #3 (N-player).

This is NOT a test that the trained strategy converges to a proven
equilibrium — for 3+ simultaneously-live players no such single, provable
target exists (see `cfr_solver/games/kuhn3p.py` and the project plan for
why). What this test verifies is that this package's N-player
generalization of `cfr.py` and `exploitability.py` behaves sensibly: each
player's individually-measured exploitability (how much they could gain by
unilaterally deviating, everyone else fixed) trends downward as self-play
training continues. This is exactly the kind of honestly-measured
(non-fabricated) evidence the project's "never invent GTO numbers"
principle requires when a proof isn't available.
"""

from __future__ import annotations

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import exploitability_per_player
from cfr_solver.games.kuhn3p import ThreePlayerKuhnPoker
from tests.test_game_interface import assert_game_is_well_formed

CHECKPOINT_LOW = 1_000
CHECKPOINT_HIGH = 10_000


def test_three_player_kuhn_poker_is_well_formed() -> None:
    assert_game_is_well_formed(ThreePlayerKuhnPoker())


def test_exploitability_per_player_matches_num_players() -> None:
    game = ThreePlayerKuhnPoker()
    solver = CFRSolver(game, variant="cfr_plus")
    solver.train(CHECKPOINT_LOW)
    gaps = exploitability_per_player(game, solver.average_strategy())
    assert len(gaps) == 3
    assert all(g >= 0 for g in gaps), (
        "a best response can never do worse than the current strategy, so "
        f"every gap must be non-negative; got {gaps}"
    )


def test_three_player_kuhn_poker_exploitability_trends_down_for_every_player() -> None:
    game = ThreePlayerKuhnPoker()
    solver = CFRSolver(game, variant="cfr_plus")

    solver.train(CHECKPOINT_LOW)
    gaps_low = exploitability_per_player(game, solver.average_strategy())

    solver.train(CHECKPOINT_HIGH - CHECKPOINT_LOW)
    gaps_high = exploitability_per_player(game, solver.average_strategy())

    for player, (low, high) in enumerate(zip(gaps_low, gaps_high)):
        assert high < low, (
            f"player {player}'s exploitability did not decrease between "
            f"{CHECKPOINT_LOW} iterations ({low}) and {CHECKPOINT_HIGH} "
            f"iterations ({high})"
        )
