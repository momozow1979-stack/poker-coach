"""External-Sampling MCCFR tests (`CFRSolver.train_external_sampling`).

Two things to check, at very different scales:

1. Correctness — does it converge to the same known answer full-tree CFR
   already reproduces on Kuhn Poker? A sampling-based algorithm with a bug
   in its importance weighting would still often look "roughly plausible"
   without this kind of ground-truth check.
2. Does it actually solve the problem it was built for? `PostflopSubgame`
   is where full-tree `train()` breaks down — 31.5s per iteration, measured
   in `BENCHMARKS.md`, because a turn/river chance node alone has ~44/~43
   outcomes to enumerate. This only needs a fast structural check in CI
   (a real convergence run — 1,000,000 iterations — is also recorded in
   BENCHMARKS.md, but takes too long for routine test runs).
"""

from __future__ import annotations

import time

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import exploitability
from cfr_solver.games.kuhn import KuhnPoker
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card

KUHN_THEORETICAL_VALUE_PLAYER0 = -1 / 18
ITERATIONS = 50_000
# Observed at ITERATIONS with random_seed=42: 0.00723. Margin added above
# that measured value, per this project's "don't fabricate a threshold
# ahead of measuring" rule (see also test_leduc_convergence.py).
EXPLOITABILITY_THRESHOLD = 0.015


def test_mccfr_converges_to_kuhn_pokers_known_equilibrium() -> None:
    game = KuhnPoker()
    solver = CFRSolver(game, variant="cfr_plus", random_seed=42)
    solver.train_external_sampling(ITERATIONS)
    avg_strategy = solver.average_strategy()

    exploit = exploitability(game, avg_strategy)
    assert exploit < EXPLOITABILITY_THRESHOLD, (
        f"MCCFR exploitability {exploit} exceeds {EXPLOITABILITY_THRESHOLD} "
        f"after {ITERATIONS} iterations"
    )


def test_mccfr_is_reproducible_given_a_seed() -> None:
    game = KuhnPoker()
    solver_a = CFRSolver(game, variant="cfr_plus", random_seed=123)
    solver_a.train_external_sampling(2_000)
    solver_b = CFRSolver(KuhnPoker(), variant="cfr_plus", random_seed=123)
    solver_b.train_external_sampling(2_000)
    assert solver_a.average_strategy() == solver_b.average_strategy()


def test_mccfr_runs_fast_on_the_game_full_tree_cfr_cannot_handle() -> None:
    """Structural check only — see module docstring. A real convergence
    measurement (1,000,000 iterations, ~370s) is recorded in BENCHMARKS.md,
    not run here."""
    board = [parse_card(c) for c in ("7h", "2d", "3s")]
    game = PostflopSubgame(board, hero_range_notation="AA", villain_range_notation="KK")
    solver = CFRSolver(game, variant="cfr_plus", random_seed=1)

    t0 = time.time()
    solver.train_external_sampling(200)
    elapsed = time.time() - t0

    # Full-tree train() measured ~31.5s for a SINGLE iteration on this same
    # game (BENCHMARKS.md). 200 sampled iterations finishing in well under
    # that is the whole point of this test.
    assert elapsed < 10.0, (
        f"200 sampled iterations took {elapsed:.1f}s — expected well under "
        "10s (full-tree train() takes ~31.5s for a single iteration here)"
    )
