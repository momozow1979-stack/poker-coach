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
"""

from __future__ import annotations

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

    def __init__(self, game: Game, variant: str = "cfr_plus") -> None:
        if variant not in ("cfr", "cfr_plus"):
            raise ValueError(f"unknown variant {variant!r}, expected 'cfr' or 'cfr_plus'")
        self.game = game
        self.variant = variant
        self._nodes: dict[str, _Node] = {}
        self._iterations_trained = 0

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

    def average_strategy(self) -> dict[str, dict[Action, float]]:
        """The (near-)equilibrium strategy: `{information_set_key: {action: probability}}`."""
        return {key: node.average_strategy() for key, node in self._nodes.items()}
