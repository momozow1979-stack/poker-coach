"""Chance-node sampling wrapper, used to make exploitability tractable on
wide-range `PostflopSubgame` instances.

`exploitability.best_response_value` and `actual_value` are exact: they walk
every chance outcome. That is fine for Kuhn/Leduc/3-player Kuhn (a handful of
outcomes per chance node) and even for the minimal `AA` vs `KK`
`PostflopSubgame` (`BENCHMARKS.md`, 217s), but it enumerates the *same*
combo x combo x turn x river product that made full-tree `train()`
intractable in the first place — widening the range makes exact
exploitability explode exactly like exact training did.

`ChanceSampledGame` wraps any `Game` and, at each distinct chance-node
history, replaces the full outcome list with `k` outcomes drawn with
replacement in proportion to their true probability, each reweighted to
`1/k`. `1/k`-weighted averaging is a standard Monte Carlo estimate of
`sum(prob * f(action))` for a *fixed* `f` — this is exactly what
`actual_value` computes (every player's action is drawn from the fixed
`avg_strategy`, so there is no `f` left to adapt), and it is unbiased there.

IMPORTANT — `best_response_value` is a different story, and NOT simply
unbiased by this same argument. It runs policy iteration: for each
information set it picks the action that maximizes value *given the current
sampled sub-game*. Averaging `E[max_policy value(policy, sample)]` over
independent samples is, by Jensen's inequality, `>= max_policy
E[value(policy, sample)]` (the true best-response value) whenever the same
sample both selects a policy and is used to score it — the greedy policy
partly overfits the specific outcomes it happened to see. Measured directly
in this package: `PostflopSubgame(AA, KK)` at 50,000 MCCFR iterations has
*exact* exploitability 1.77926; sampling `k=5` turn/river outcomes and
averaging 10 independent replicates gives 2.04555 ± 0.04067 — noticeably
above the true value, and outside the reported standard error, exactly the
directional bias Jensen's inequality predicts.

This bias only appears where the sampled chance node sits *between* two
decisions of the same responding player whose information sets don't
already fully distinguish the sampled outcome — i.e. exactly the situation
where the greedy policy has room to specialize to the sample. Treat any
`exploitability_mc` result as an optimistic (upper-bound-leaning) estimate
that tightens toward the true value as `k` grows — never as an unbiased
replacement for the exact computation, and never report it without this
caveat attached.

CORRECTION (this paragraph originally claimed more than is true — recorded
here rather than silently deleted, since a later session spent real effort
disproving it and that's worth keeping visible): sampling *which combos*
are dealt is **not** simply "safe" the way sampling turn/river is simply
"biased". An attempt to build a combo-pair sampling tool on that claim
(`ComboSampledGame`, since reverted — see `BENCHMARKS.md`, "コンボペア
サンプリングの検証と撤回") found it introduces bias just as large as
turn/river sampling, for a subtler reason: `PostflopSubgame` deals hero's
combo first and villain's combo second, *conditioned on* hero's already-
dealt combo (villain's `chance_outcomes` filters out combos that clash with
hero's hand). That means villain's combo-dealing chance node occurs at a
different `history` for every one of hero's combos, so sampling it —
independently, per history, as `ChanceSampledGame`/`ComboSampledGame` both
naively do — makes *which* villain combos got explored vary with hero's
combo, a variable villain's own information sets don't include either. The
result is the identical aggregate-then-maximize shape that biases
turn/river sampling, just triggered by a different mechanism (a sample that
implicitly depends on a hidden variable, rather than an outcome revealed
after an earlier decision). Only the very first chance node in the tree
(the one whose `history` doesn't depend on any other hidden variable) was
verified safe to sample this way, and only for the player whose own
information sets include it — a narrow enough case that it wasn't judged
worth shipping on its own. Sampling here should be treated as unsolved,
not as "solved for combos, unsolved for turn/river".

The same sampled outcomes are reused across every visit to the same history
(cached by `history`, which is hashable in every game in this package). This
matters specifically for `best_response_value`'s policy iteration: it walks
the tree many times (once per sweep) accumulating a running q-value per
information set. If a chance node re-sampled fresh outcomes on every sweep,
the q-value accumulation itself would be noisy from sweep to sweep and the
greedy policy could oscillate forever instead of converging. Caching by
history makes one `ChanceSampledGame` instance behave like a single fixed
(but randomly drawn) sub-game across an entire `best_response_value` or
`actual_value` call, which is what policy iteration's convergence proof
actually requires.
"""

from __future__ import annotations

import random
import statistics

from cfr_solver.exploitability import exploitability
from cfr_solver.games.game import Action, Game, History


class ChanceSampledGame(Game):
    def __init__(self, game: Game, samples_per_chance_node: int, *, random_seed: int) -> None:
        self._game = game
        self._k = samples_per_chance_node
        self._rng = random.Random(random_seed)
        self._cache: dict[History, list[tuple[Action, float]]] = {}

    @property
    def num_players(self) -> int:
        return self._game.num_players

    def new_initial_history(self) -> History:
        return self._game.new_initial_history()

    def is_terminal(self, history: History) -> bool:
        return self._game.is_terminal(history)

    def is_chance_node(self, history: History) -> bool:
        return self._game.is_chance_node(history)

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        cached = self._cache.get(history)
        if cached is not None:
            return cached

        outcomes = self._game.chance_outcomes(history)
        if len(outcomes) <= self._k:
            sampled = outcomes
        else:
            actions = [a for a, _p in outcomes]
            weights = [p for _a, p in outcomes]
            drawn = self._rng.choices(actions, weights=weights, k=self._k)
            sampled = [(a, 1.0 / self._k) for a in drawn]

        self._cache[history] = sampled
        return sampled

    def current_player(self, history: History) -> int:
        return self._game.current_player(history)

    def legal_actions(self, history: History) -> list[Action]:
        return self._game.legal_actions(history)

    def next_history(self, history: History, action: Action) -> History:
        return self._game.next_history(history, action)

    def returns(self, history: History) -> list[float]:
        return self._game.returns(history)

    def information_set_key(self, history: History, player: int) -> str:
        return self._game.information_set_key(history, player)


def exploitability_mc(
    game: Game,
    avg_strategy: dict[str, dict[Action, float]],
    *,
    samples_per_chance_node: int,
    replicates: int,
    base_seed: int,
) -> tuple[float, float]:
    """Mean and standard error of `exploitability()` over `replicates`
    independent `ChanceSampledGame` draws.

    Each replicate is one full, independently-seeded Monte Carlo estimate
    (its own `ChanceSampledGame`, its own cache) — not a single sample
    reused `replicates` times. The standard error (`stdev / sqrt(n)`) is
    returned alongside the mean so a caller can see how much sampling noise
    remains, rather than reporting a single point estimate as if it were
    exact.
    """
    values = [
        exploitability(ChanceSampledGame(game, samples_per_chance_node, random_seed=base_seed + i), avg_strategy)
        for i in range(replicates)
    ]
    mean = statistics.mean(values)
    stderr = statistics.stdev(values) / (replicates**0.5) if replicates > 1 else float("nan")
    return mean, stderr
