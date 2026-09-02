"""Leduc Hold'em convergence test — verification benchmark #2.

Unlike Kuhn Poker there is no simple closed-form equilibrium value to check
against here, so this test is built in two layers, deliberately avoiding
fabricating a threshold ahead of running the trainer (see `BENCHMARKS.md`):

1. An unconditional assertion that's safe to hardcode: exploitability
   strictly decreases as training continues. This only claims "CFR+ is
   converging on this game," not any absolute number.
2. An absolute-threshold assertion whose value was set AFTER actually
   running this trainer and recording the observed exploitability in
   `BENCHMARKS.md`, with margin added above the observed value.

Iteration counts are kept modest (a full-tree, pure-Python CFR+ pass over
this game's ~9,500-history tree costs real wall-clock time) so this stays a
reasonable CI cost while still clearly demonstrating the convergence trend
recorded in the literature this game is drawn from (Southey et al., 2005;
Lanctot et al., 2009).
"""

from __future__ import annotations

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import exploitability
from cfr_solver.games.leduc import LeducHoldem
from tests.test_game_interface import assert_game_is_well_formed

CHECKPOINT_LOW = 1_000
CHECKPOINT_HIGH = 5_000

# Observed in BENCHMARKS.md at CHECKPOINT_HIGH: 0.014839. Margin added above
# that measured value — this is not a value chosen before running the trainer.
EXPLOITABILITY_THRESHOLD_AT_HIGH_CHECKPOINT = 0.02


def test_leduc_holdem_is_well_formed() -> None:
    assert_game_is_well_formed(LeducHoldem())


def test_leduc_exploitability_decreases_with_more_training() -> None:
    game = LeducHoldem()
    solver = CFRSolver(game, variant="cfr_plus")

    solver.train(CHECKPOINT_LOW)
    exploit_low = exploitability(game, solver.average_strategy())

    solver.train(CHECKPOINT_HIGH - CHECKPOINT_LOW)
    exploit_high = exploitability(game, solver.average_strategy())

    assert exploit_high < exploit_low, (
        f"exploitability did not decrease between {CHECKPOINT_LOW} iterations "
        f"({exploit_low}) and {CHECKPOINT_HIGH} iterations ({exploit_high})"
    )
    assert exploit_high < EXPLOITABILITY_THRESHOLD_AT_HIGH_CHECKPOINT, (
        f"exploitability {exploit_high} at {CHECKPOINT_HIGH} iterations exceeds "
        f"the recorded threshold {EXPLOITABILITY_THRESHOLD_AT_HIGH_CHECKPOINT} "
        "(see BENCHMARKS.md for the measurement this margin was set from)"
    )
