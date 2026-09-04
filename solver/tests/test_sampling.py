"""`ChanceSampledGame` / `exploitability_mc` — the tool used to make
exploitability tractable on wide-range `PostflopSubgame` instances
(`BENCHMARKS.md`, "レンジ幅を広げる" section) once exact enumeration of the
turn/river chance nodes becomes too expensive.

Leduc Hold'em is used here (not `PostflopSubgame`) because it is cheap
enough to also compute the EXACT value to compare against, and its board
chance node (4 outcomes, occurring between the two betting rounds, with
round 1's information sets *not* including the board) is structurally the
same shape as `PostflopSubgame`'s turn/river deal — see `sampling.py`'s
module docstring for why that shape is exactly what makes best-response
sampling biased.
"""

from __future__ import annotations

import statistics

from cfr_solver.cfr import CFRSolver
from cfr_solver.exploitability import actual_value, exploitability
from cfr_solver.games.leduc import LeducHoldem
from cfr_solver.sampling import ChanceSampledGame, exploitability_mc

TRAIN_ITERATIONS = 1_000


def _trained_avg_strategy() -> tuple[LeducHoldem, dict]:
    game = LeducHoldem()
    solver = CFRSolver(game, variant="cfr_plus", random_seed=0)
    solver.train(TRAIN_ITERATIONS)
    return game, solver.average_strategy()


def test_chance_outcomes_always_sum_to_one() -> None:
    game, avg = _trained_avg_strategy()
    sampled = ChanceSampledGame(game, samples_per_chance_node=2, random_seed=1)

    def walk(history) -> None:
        if game.is_terminal(history):
            return
        if game.is_chance_node(history):
            outcomes = sampled.chance_outcomes(history)
            total = sum(p for _a, p in outcomes)
            assert abs(total - 1.0) < 1e-9, f"chance_outcomes for {history!r} sum to {total}"
            for action, _p in outcomes:
                walk(sampled.next_history(history, action))
            return
        for action in sampled.legal_actions(history):
            walk(sampled.next_history(history, action))

    walk(sampled.new_initial_history())


def test_full_arity_k_is_an_exact_passthrough() -> None:
    """k >= every chance node's outcome count (Leduc's max is 6, the initial
    deal) means nothing is actually sampled — `ChanceSampledGame` must then
    reproduce the exact computation exactly, not approximately."""
    game, avg = _trained_avg_strategy()
    exact = exploitability(game, avg)
    passthrough = exploitability(ChanceSampledGame(game, samples_per_chance_node=6, random_seed=1), avg)
    assert passthrough == exact


def test_actual_value_under_sampling_is_unbiased() -> None:
    """`actual_value` never adapts a policy to the sample (every player's
    action comes from the fixed `avg_strategy`), so unlike best-response
    sampling, averaging it over independent replicates has no Jensen-gap
    bias — its mean should track the exact value within the estimate's own
    sampling noise (not a fixed absolute tolerance: sampling every chance
    node, including the initial 6/5-outcome deal, down to k=3 is noisy per
    replicate, so the check has to be against the measured standard error,
    the same way `exploitability_mc` reports one instead of a bare number).
    """
    game, avg = _trained_avg_strategy()
    exact = actual_value(game, avg)

    replicates = 300
    samples: list[list[float]] = [[], []]
    for i in range(replicates):
        sampled_game = ChanceSampledGame(game, samples_per_chance_node=3, random_seed=1000 + i)
        values = actual_value(sampled_game, avg)
        for p in range(2):
            samples[p].append(values[p])

    for p in range(2):
        mean = statistics.mean(samples[p])
        stderr = statistics.stdev(samples[p]) / (replicates**0.5)
        assert abs(mean - exact[p]) < 5 * stderr, (
            f"player {p}: sampled actual_value mean {mean} (stderr {stderr}) strayed "
            f"from the exact value {exact[p]} by more than 5 standard errors"
        )


def test_best_response_sampling_is_upward_biased() -> None:
    """Documented in `sampling.py`: sampling a chance node that sits between
    two decisions of the same responding player (Leduc's board deal, between
    round 1 and round 2 betting) lets the greedy best-response policy
    specialize to whichever outcomes it happened to see, which provably
    biases the estimate upward (Jensen's inequality) relative to the exact
    best-response value. This is a known, directional property of the
    estimator, not a bug — this test pins the direction so a future change
    that accidentally "fixes" it (making the estimate track the exact value
    too closely at tiny k) gets noticed rather than quietly assumed to be an
    improvement.
    """
    game, avg = _trained_avg_strategy()
    exact = exploitability(game, avg)

    mean, stderr = exploitability_mc(game, avg, samples_per_chance_node=2, replicates=30, base_seed=42)

    assert mean > exact, (
        f"expected the small-k sampled estimate ({mean}) to overshoot the exact "
        f"exploitability ({exact}) per the documented upward bias, but it did not"
    )
    assert mean - exact > 2 * stderr, (
        "expected the overshoot to be well outside sampling noise "
        f"(mean={mean}, exact={exact}, stderr={stderr})"
    )
