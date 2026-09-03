"""Kuhn Poker convergence test — verification benchmark #1.

Confirms this package's generic CFR+ implementation converges to Kuhn
Poker's known Nash equilibrium value on a game it was NOT hand-tuned for
(the trainer, exploitability calculator, and game definition are all
written generically). See `cfr_solver/games/kuhn.py` and `BENCHMARKS.md`
for the theoretical value and its citation.
"""

from __future__ import annotations

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import actual_value, exploitability
from cfr_solver.games.kuhn import KuhnPoker
from tests.test_game_interface import assert_game_is_well_formed

KUHN_THEORETICAL_VALUE_PLAYER0 = -1 / 18
TRAINING_ITERATIONS = 100_000
TOLERANCE = 1e-3


def test_kuhn_poker_is_well_formed() -> None:
    assert_game_is_well_formed(KuhnPoker())


def test_kuhn_poker_converges_to_known_equilibrium_value() -> None:
    game = KuhnPoker()
    solver = CFRSolver(game, variant="cfr_plus")
    solver.train(TRAINING_ITERATIONS)
    avg_strategy = solver.average_strategy()

    value = actual_value(game, avg_strategy)
    assert value[0] == -value[1], "game must be zero-sum"
    assert abs(value[0] - KUHN_THEORETICAL_VALUE_PLAYER0) < TOLERANCE, (
        f"player 0's value {value[0]} is not within {TOLERANCE} of the known "
        f"theoretical equilibrium value {KUHN_THEORETICAL_VALUE_PLAYER0} (-1/18)"
    )


def test_kuhn_poker_trained_strategy_has_low_exploitability() -> None:
    game = KuhnPoker()
    solver = CFRSolver(game, variant="cfr_plus")
    solver.train(TRAINING_ITERATIONS)
    avg_strategy = solver.average_strategy()

    exploit = exploitability(game, avg_strategy)
    assert exploit < TOLERANCE, (
        f"exploitability {exploit} is not below {TOLERANCE} after "
        f"{TRAINING_ITERATIONS} iterations"
    )
