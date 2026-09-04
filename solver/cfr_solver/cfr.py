"""Generic CFR / CFR+ trainer.

Written entirely against the `Game` interface in `games/game.py` — nothing
here is specific to Kuhn Poker, Leduc Hold'em, or any other game. The player
count is a variable N (0..N-1), not hardcoded to 2, so the same trainer runs
unmodified on 2-player games (Kuhn, Leduc) and N-player self-play games
(3-player Kuhn now; a multiway preflop game in a later phase).

CFR+ (Tammelin et al., 2015, "Solving Heads-up Limit Texas Hold'em") is the
default: regrets are floored at zero after every update (not just when
reading out the current strategy), and the strategy sum is weighted linearly
by iteration number so later, better-converged iterations count more toward
the reported average strategy. Vanilla CFR (Zinkevich et al., 2007) is kept
available via `variant="cfr"` for comparison — regrets are allowed to go
negative in the accumulator (only floored at read-time via regret matching),
and the strategy sum is weighted uniformly by the acting player's own reach
probability.

`train()` walks the *entire* tree every iteration — chance nodes included,
enumerating every outcome. That's fine for Kuhn/Leduc/a single betting round,
but `BENCHMARKS.md`'s `PostflopSubgame` measurement shows exactly where it
breaks: a turn or river chance node alone has ~44/~43 outcomes, so a
connected flop→turn→river tree is dominated by chance-node branching, not by
the (2-3 action) betting decisions. `train_external_sampling()` is the fix
for that specific bottleneck: External-Sampling MCCFR (Lanctot et al., 2009,
"Monte Carlo Sampling for Regret Minimization in Extensive Games") samples
chance outcomes and the *non-traversing* player's actions (one draw each,
instead of enumerating every branch) while still exploring the traversing
player's own actions exhaustively (so its regret updates stay exact, not
sampled). It is proven to converge to the same equilibrium as full CFR, just
with cheaper, noisier iterations — see `docs/ai-prompts.md`-style principle
1 applied to this module: don't claim it converges faster in wall-clock time
without measuring it (`BENCHMARKS.md` records the actual measurement).

## Per-information-set storage (`BENCHMARKS.md`, "情報集合の保存方式")

Widening `PostflopSubgame`'s ranges makes the number of information sets
grow into the tens of millions, at which point the storage this trainer
picks for each one dominates total memory far more than anything about CFR
itself. A per-node Python object holding two `dict[Action, float]`
accumulators (the original design) measured ~720 bytes/information-set,
purely from CPython dict/object overhead — the same 2-3 floats packed into
a flat `array.array` instead cost as little as ~220 bytes/information-set
for the *same numbers, computed the same way* (verified with an
exact-equality regression test, `tests/test_node_storage_regression.py`:
no floating-point operation here is reordered by this storage change, so
results before and after are bit-for-bit identical, not just "close").

Concretely: every information set gets an integer id (`_index[key]`); its
regret/strategy accumulators live in one flat `_regret` / `_strategy`
`array.array('d')` shared across *all* information sets, at
`[id * STRIDE : id * STRIDE + n_actions]`; and its action vocabulary is a
shared, interned tuple (`_ActionSet`, looked up via `_action_set_lookup`) —
this codebase's games only ever have a handful of distinct action
vocabularies (`("x","b")`, `("f","c")`, `("f","c","b")`, ...), so caching
them costs nothing asymptotically while letting tens of millions of
information sets each hold just a 1-byte index into that small cache
instead of allocating their own list. `STRIDE` (currently 3) is a real
constraint, not a magic number: it's the most actions any information set
in this package's games has ever needed, and `_get_node_id` raises loudly
if a future game ever needs more, rather than silently corrupting a
neighboring node's slots.

`array.array`'s own `.extend()` already amortizes growth (same
doubling-style strategy CPython's `list` uses internally), so there is no
hand-rolled capacity/resize logic here to get wrong.
"""

from __future__ import annotations

import random
from array import array
from dataclasses import dataclass, field

from cfr_solver.games.game import Action, Game, History

STRIDE = 3  # the most actions any information set in this package needs


def _naive_sum(values: list[float]) -> float:
    """Plain left-to-right float summation — deliberately not the builtin
    `sum()`. CPython 3.12 made `sum()` use Neumaier-compensated summation
    for floats (more accurate, but a *different* rounding than 3.11 and
    earlier's naive addition) — pinning the algorithm here keeps this
    trainer's output independent of which CPython minor version runs it,
    which `tests/test_node_storage_regression.py`'s bit-exact fixture
    (captured once, compared forever) depends on."""
    total = 0.0
    for v in values:
        total += v
    return total


@dataclass(frozen=True)
class _ActionSet:
    """A shared, immutable action vocabulary. `actions` is never mutated —
    sharing one instance across every information set with the same
    vocabulary is what lets that cost stay flat regardless of how many
    information sets exist."""

    actions: tuple[Action, ...]
    index: dict[Action, int] = field(compare=False)


class CFRSolver:
    """Trains a `Game` via CFR or CFR+ self-play and reports the average strategy."""

    def __init__(
        self, game: Game, variant: str = "cfr_plus", *, random_seed: int | None = None
    ) -> None:
        if variant not in ("cfr", "cfr_plus"):
            raise ValueError(f"unknown variant {variant!r}, expected 'cfr' or 'cfr_plus'")
        self.game = game
        self.variant = variant
        self._index: dict[str, int] = {}
        self._action_set_lookup: dict[tuple[Action, ...], int] = {}
        self._action_sets: list[_ActionSet] = []
        self._node_action_set_id = array("B")
        self._regret = array("d")
        self._strategy = array("d")
        self._iterations_trained = 0
        self._sampled_iterations_trained = 0
        self._rng = random.Random(random_seed)

    def _get_action_set_id(self, actions: list[Action]) -> int:
        canon = tuple(actions)
        aset_id = self._action_set_lookup.get(canon)
        if aset_id is not None:
            return aset_id
        if len(canon) > STRIDE:
            raise RuntimeError(
                f"action set {canon!r} has {len(canon)} actions, exceeding STRIDE={STRIDE} "
                "— widen STRIDE in cfr.py for a game that legitimately needs more"
            )
        aset_id = len(self._action_sets)
        self._action_sets.append(
            _ActionSet(actions=canon, index={a: i for i, a in enumerate(canon)})
        )
        self._action_set_lookup[canon] = aset_id
        return aset_id

    def _get_node_id(self, key: str, actions: list[Action]) -> int:
        nid = self._index.get(key)
        if nid is not None:
            return nid
        nid = len(self._index)
        self._index[key] = nid
        self._node_action_set_id.append(self._get_action_set_id(actions))
        self._regret.extend([0.0] * STRIDE)
        self._strategy.extend([0.0] * STRIDE)
        return nid

    def _action_set_for(self, nid: int) -> _ActionSet:
        return self._action_sets[self._node_action_set_id[nid]]

    def _current_strategy(self, nid: int) -> dict[Action, float]:
        """Regret matching: strategy proportional to positive regret.

        Uniform if every action has non-positive regret. This same
        computation is correct for both variants — under CFR+ the
        accumulator is already floored at zero by the update rule, so
        `max(0, r)` here is a no-op; under vanilla CFR the accumulator can
        go negative, and this is exactly where the projection back onto
        positive regret happens.
        """
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        n = len(aset.actions)
        positive = [max(0.0, self._regret[base + i]) for i in range(n)]
        total = _naive_sum(positive)
        if total > 0:
            return {a: v / total for a, v in zip(aset.actions, positive)}
        return {a: 1.0 / n for a in aset.actions}

    def _average_strategy_for(self, nid: int) -> dict[Action, float]:
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        n = len(aset.actions)
        values = [self._strategy[base + i] for i in range(n)]
        total = _naive_sum(values)
        if total > 0:
            return {a: v / total for a, v in zip(aset.actions, values)}
        return {a: 1.0 / n for a in aset.actions}

    def train(self, iterations: int) -> None:
        num_players = self.game.num_players
        for i in range(1, iterations + 1):
            iteration = self._iterations_trained + i
            self._cfr(
                self.game.new_initial_history(),
                reach_probs=[1.0] * num_players,
                iteration=iteration,
            )
        self._iterations_trained += iterations

    def _cfr(self, history: History, reach_probs: list[float], iteration: int) -> list[float]:
        game = self.game

        if game.is_terminal(history):
            return list(game.returns(history))

        if game.is_chance_node(history):
            num_players = game.num_players
            total = [0.0] * num_players
            for action, prob in game.chance_outcomes(history):
                child_util = self._cfr(game.next_history(history, action), reach_probs, iteration)
                for p in range(num_players):
                    total[p] += prob * child_util[p]
            return total

        player = game.current_player(history)
        actions = game.legal_actions(history)
        key = game.information_set_key(history, player)
        nid = self._get_node_id(key, actions)
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        strategy = self._current_strategy(nid)

        num_players = game.num_players
        action_utils: dict[Action, list[float]] = {}
        node_util = [0.0] * num_players
        for action in actions:
            child_reach = list(reach_probs)
            child_reach[player] *= strategy[action]
            util = self._cfr(game.next_history(history, action), child_reach, iteration)
            action_utils[action] = util
            for p in range(num_players):
                node_util[p] += strategy[action] * util[p]

        # Counterfactual reach: probability of reaching this history under
        # every OTHER player's (and chance's, already folded in above)
        # strategy, excluding the acting player's own contribution.
        cf_reach = 1.0
        for p in range(num_players):
            if p != player:
                cf_reach *= reach_probs[p]

        for action in actions:
            slot = base + aset.index[action]
            regret = action_utils[action][player] - node_util[player]
            updated = self._regret[slot] + cf_reach * regret
            if self.variant == "cfr_plus":
                updated = max(0.0, updated)
            self._regret[slot] = updated

        own_reach = reach_probs[player]
        weight = own_reach * (iteration if self.variant == "cfr_plus" else 1.0)
        for action in actions:
            slot = base + aset.index[action]
            self._strategy[slot] += weight * strategy[action]

        return node_util

    def train_external_sampling(self, iterations: int) -> None:
        """External-Sampling MCCFR — one traversal per player per iteration.

        Shares the same flat storage (and therefore the same
        `average_strategy()`) as `train()`, so the two can even be mixed on
        the same solver instance, though that isn't a configuration this
        package currently tests.
        """
        num_players = self.game.num_players
        for i in range(1, iterations + 1):
            iteration = self._sampled_iterations_trained + i
            for traverser in range(num_players):
                self._external_sampling(self.game.new_initial_history(), traverser, iteration)
        self._sampled_iterations_trained += iterations

    def _external_sampling(self, history: History, traverser: int, iteration: int) -> list[float]:
        game = self.game

        if game.is_terminal(history):
            return list(game.returns(history))

        if game.is_chance_node(history):
            outcomes = game.chance_outcomes(history)
            actions = [a for a, _p in outcomes]
            weights = [p for _a, p in outcomes]
            sampled = self._rng.choices(actions, weights=weights, k=1)[0]
            return self._external_sampling(game.next_history(history, sampled), traverser, iteration)

        num_players = game.num_players
        player = game.current_player(history)
        actions = game.legal_actions(history)
        key = game.information_set_key(history, player)
        nid = self._get_node_id(key, actions)
        aset = self._action_set_for(nid)
        base = nid * STRIDE
        strategy = self._current_strategy(nid)

        if player == traverser:
            # Traverser's own decision: explored exhaustively, exactly like
            # full CFR, so its regret update is exact — only the OPPONENT
            # and CHANCE branches below are sampled. No counterfactual-reach
            # weighting is needed here (unlike `_cfr`): the opponent/chance
            # sampling already makes this an unbiased estimator of the true
            # counterfactual value on its own (Lanctot et al., 2009).
            action_utils: dict[Action, list[float]] = {}
            node_util = [0.0] * num_players
            for action in actions:
                util = self._external_sampling(
                    game.next_history(history, action), traverser, iteration
                )
                action_utils[action] = util
                for p in range(num_players):
                    node_util[p] += strategy[action] * util[p]

            for action in actions:
                slot = base + aset.index[action]
                regret = action_utils[action][traverser] - node_util[traverser]
                updated = self._regret[slot] + regret
                if self.variant == "cfr_plus":
                    updated = max(0.0, updated)
                self._regret[slot] = updated

            return node_util

        # A non-traverser's decision: record the full mixed strategy into
        # strategy_sum (as usual — this is what makes the average strategy
        # converge for THIS player once it's their turn to be the
        # traverser), but only recurse into one action sampled from it.
        weight = iteration if self.variant == "cfr_plus" else 1.0
        for action in actions:
            slot = base + aset.index[action]
            self._strategy[slot] += weight * strategy[action]

        sampled_action = self._rng.choices(actions, weights=[strategy[a] for a in actions], k=1)[0]
        return self._external_sampling(
            game.next_history(history, sampled_action), traverser, iteration
        )

    def average_strategy(self) -> dict[str, dict[Action, float]]:
        """The (near-)equilibrium strategy: `{information_set_key: {action: probability}}`."""
        return {key: self._average_strategy_for(nid) for key, nid in self._index.items()}

    @property
    def num_information_sets(self) -> int:
        return len(self._index)
