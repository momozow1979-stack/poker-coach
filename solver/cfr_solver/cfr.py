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
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from cfr_solver.games.game import Action, Game, History


@dataclass
class _Node:
    """Per-information-set accumulators."""

    actions: list[Action]
    regret_sum: dict[Action, float] = field(default_factory=dict)
    strategy_sum: dict[Action, float] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for a in self.actions:
            self.regret_sum.setdefault(a, 0.0)
            self.strategy_sum.setdefault(a, 0.0)

    def current_strategy(self) -> dict[Action, float]:
        """Regret matching: strategy proportional to positive regret.

        Uniform if every action has non-positive regret. This same
        computation is correct for both variants — under CFR+ the
        accumulator is already floored at zero by the update rule, so
        `max(0, r)` here is a no-op; under vanilla CFR the accumulator can
        go negative, and this is exactly where the projection back onto
        positive regret happens.
        """
        positive = {a: max(0.0, r) for a, r in self.regret_sum.items()}
        total = sum(positive.values())
        if total > 0:
            return {a: v / total for a, v in positive.items()}
        n = len(self.actions)
        return {a: 1.0 / n for a in self.actions}

    def average_strategy(self) -> dict[Action, float]:
        total = sum(self.strategy_sum.values())
        if total > 0:
            return {a: v / total for a, v in self.strategy_sum.items()}
        n = len(self.actions)
        return {a: 1.0 / n for a in self.actions}


class CFRSolver:
    """Trains a `Game` via CFR or CFR+ self-play and reports the average strategy."""

    def __init__(
        self, game: Game, variant: str = "cfr_plus", *, random_seed: int | None = None
    ) -> None:
        if variant not in ("cfr", "cfr_plus"):
            raise ValueError(f"unknown variant {variant!r}, expected 'cfr' or 'cfr_plus'")
        self.game = game
        self.variant = variant
        self._nodes: dict[str, _Node] = {}
        self._iterations_trained = 0
        self._sampled_iterations_trained = 0
        self._rng = random.Random(random_seed)

    def _get_node(self, key: str, actions: list[Action]) -> _Node:
        node = self._nodes.get(key)
        if node is None:
            node = _Node(actions=list(actions))
            self._nodes[key] = node
        return node

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
        node = self._get_node(key, actions)
        strategy = node.current_strategy()

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
            regret = action_utils[action][player] - node_util[player]
            updated = node.regret_sum[action] + cf_reach * regret
            if self.variant == "cfr_plus":
                updated = max(0.0, updated)
            node.regret_sum[action] = updated

        own_reach = reach_probs[player]
        weight = own_reach * (iteration if self.variant == "cfr_plus" else 1.0)
        for action in actions:
            node.strategy_sum[action] += weight * strategy[action]

        return node_util

    def train_external_sampling(self, iterations: int) -> None:
        """External-Sampling MCCFR — one traversal per player per iteration.

        Shares the same `_Node` accumulators (and therefore the same
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
        node = self._get_node(key, actions)
        strategy = node.current_strategy()

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
                regret = action_utils[action][traverser] - node_util[traverser]
                updated = node.regret_sum[action] + regret
                if self.variant == "cfr_plus":
                    updated = max(0.0, updated)
                node.regret_sum[action] = updated

            return node_util

        # A non-traverser's decision: record the full mixed strategy into
        # strategy_sum (as usual — this is what makes the average strategy
        # converge for THIS player once it's their turn to be the
        # traverser), but only recurse into one action sampled from it.
        weight = iteration if self.variant == "cfr_plus" else 1.0
        for action in actions:
            node.strategy_sum[action] += weight * strategy[action]

        sampled_action = self._rng.choices(actions, weights=[strategy[a] for a in actions], k=1)[0]
        return self._external_sampling(
            game.next_history(history, sampled_action), traverser, iteration
        )

    def average_strategy(self) -> dict[str, dict[Action, float]]:
        """The (near-)equilibrium strategy: `{information_set_key: {action: probability}}`."""
        return {key: node.average_strategy() for key, node in self._nodes.items()}
