"""A single real heads-up postflop betting round on a fixed board (3-5 cards:
flop, turn, or a complete runout) — Phase 2's
first non-toy benchmark: real 52-card hand evaluation and range data
imported from the app's own range notation, instead of a 3-6 card toy deck.

**Scope chosen for this first measurement** (see `solver/BENCHMARKS.md` for
the actual numbers and the reasoning): the app's real BTN-open vs BB-call
ranges (`lib/features/range_chart/infrastructure/range_definitions.dart`)
produce roughly 650 x 470 combos on a fixed board — an order of magnitude
too large for a full-tree, pure-Python CFR pass (verified by direct
measurement, not assumed). Rather than guess at a card-abstraction scheme
whose correctness would itself need separate validation, this first
benchmark narrows the SAME real notation to just its pairs component
(`'22+'` for the raiser, the pairs portion of `'22-88, ...'` for the
caller) — still genuine range data and a real, meaningful spot ("who's
ahead when both hold a pocket pair on a dry ace-high flop"), just a
deliberately smaller slice, chosen so the plan's performance gate can be
evaluated on real timing data. Widening the range is exactly the subject
of that gate, not something to guess at up front.

Dealing is exact — hero and villain combos are drawn without replacement
from the real 52-card deck (excluding board cards, and, for the villain
deal, any card clash with hero's already-dealt combo) — the same pattern
`games/leduc.py` uses for its 6-card deck, just with a real hand evaluator
instead of a hand-vs-hand rank comparison. No card-bucketing approximation
is used: every information set is a real, distinct 2-card combo, so this
game's correctness rests on the same already-verified `Game`/`cfr.py`/
`exploitability.py` machinery as Kuhn and Leduc, not on new approximation
logic that would need its own proof.
"""

from __future__ import annotations

from cfr_solver.games.game import Action, Game, History
from cfr_solver.poker.cards import evaluate_best_hand
from cfr_solver.poker.combos import Combo, range_combos
from cfr_solver.poker.range_notation import expand as expand_range


def _round_done(tokens: str) -> bool:
    return tokens == "xx" or (bool(tokens) and tokens[-1] in ("c", "f"))


def _legal_for_tokens(tokens: str, max_wagers: int) -> list[Action]:
    if tokens == "" or tokens[-1] == "x":
        return ["x", "b"]
    if tokens[-1] == "b":
        if tokens.count("b") < max_wagers:
            return ["f", "c", "b"]
        return ["f", "c"]
    raise ValueError(f"legal_actions called on a completed round: {tokens!r}")


def _simulate_round(tokens: str, bet_size: float) -> tuple[list[float], int | None]:
    contrib = [0.0, 0.0]
    level = 0.0
    actor = 0
    for ch in tokens:
        if ch == "b":
            level += bet_size
            contrib[actor] = level
        elif ch == "c":
            contrib[actor] = level
        elif ch == "f":
            return contrib, actor
        actor = 1 - actor
    return contrib, None


class FlopSubgame(Game):
    """Player 0 ("hero") acts first — modeling the preflop raiser continuing
    as first-to-act. (Real position depends on the exact preflop action;
    this benchmark does not model who was actually last to act preflop.)
    """

    def __init__(
        self,
        board: list[int],
        hero_range_notation: str,
        villain_range_notation: str,
        *,
        preflop_contrib: tuple[float, float] = (2.5, 2.5),
        bet_size: float = 2.5,
        max_wagers_per_round: int = 2,
    ) -> None:
        if len(board) not in (3, 4, 5):
            raise ValueError("FlopSubgame expects a fixed board of 3-5 cards (flop/turn/river)")
        self.board: tuple[int, ...] = tuple(board)
        blocked = set(board)
        self.hero_combos: list[Combo] = range_combos(expand_range(hero_range_notation), blocked)
        self.villain_combos: list[Combo] = range_combos(
            expand_range(villain_range_notation), blocked
        )
        if not self.hero_combos or not self.villain_combos:
            raise ValueError("a range produced zero combos after removing board cards")
        self.preflop_contrib = preflop_contrib
        self.bet_size = bet_size
        self.max_wagers_per_round = max_wagers_per_round
        self._equity_cache: dict[tuple[Combo, Combo], float] = {}

    @property
    def num_players(self) -> int:
        return 2

    def new_initial_history(self) -> History:
        return (None, None, "")

    def is_chance_node(self, history: History) -> bool:
        hero_combo, villain_combo, _actions = history
        return hero_combo is None or villain_combo is None

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        hero_combo, villain_combo, _actions = history
        if hero_combo is None:
            n = len(self.hero_combos)
            return [(str(i), 1 / n) for i in range(n)]
        live = [
            i for i, combo in enumerate(self.villain_combos) if not (set(combo) & set(hero_combo))
        ]
        if not live:
            raise RuntimeError(
                "every villain combo clashes with hero's dealt combo — ranges too "
                "narrow/overlapping for this board"
            )
        return [(str(i), 1 / len(live)) for i in live]

    def next_history(self, history: History, action: Action) -> History:
        hero_combo, villain_combo, actions = history
        if hero_combo is None:
            return (self.hero_combos[int(action)], villain_combo, actions)
        if villain_combo is None:
            return (hero_combo, self.villain_combos[int(action)], actions)
        return (hero_combo, villain_combo, actions + action)

    def is_terminal(self, history: History) -> bool:
        hero_combo, villain_combo, actions = history
        if hero_combo is None or villain_combo is None:
            return False
        return _round_done(actions)

    def current_player(self, history: History) -> int:
        _hero_combo, _villain_combo, actions = history
        return len(actions) % 2

    def legal_actions(self, history: History) -> list[Action]:
        _hero_combo, _villain_combo, actions = history
        return _legal_for_tokens(actions, self.max_wagers_per_round)

    def returns(self, history: History) -> list[float]:
        hero_combo, villain_combo, actions = history
        contrib, folder = _simulate_round(actions, self.bet_size)
        total = [self.preflop_contrib[0] + contrib[0], self.preflop_contrib[1] + contrib[1]]
        pot = sum(total)

        if folder is not None:
            winner = 1 - folder
            result = [0.0, 0.0]
            result[winner] = pot - total[winner]
            result[folder] = -total[folder]
            return result

        equity = self._equity(hero_combo, villain_combo)
        return [equity * pot - total[0], (1 - equity) * pot - total[1]]

    def _equity(self, hero_combo: Combo, villain_combo: Combo) -> float:
        key = (hero_combo, villain_combo)
        cached = self._equity_cache.get(key)
        if cached is not None:
            return cached
        hero_rank = evaluate_best_hand(list(hero_combo) + list(self.board))
        villain_rank = evaluate_best_hand(list(villain_combo) + list(self.board))
        if hero_rank > villain_rank:
            equity = 1.0
        elif hero_rank < villain_rank:
            equity = 0.0
        else:
            equity = 0.5
        self._equity_cache[key] = equity
        return equity

    def information_set_key(self, history: History, player: int) -> str:
        """Compact, injective encoding — see `postflop_subgame.py`'s
        `information_set_key` docstring for why (2-digit card ids instead
        of tuple `repr()`, `|` kept before the single action-history field
        so its own characters never collide with the digit run)."""
        hero_combo, villain_combo, actions = history
        own_combo = hero_combo if player == 0 else villain_combo
        for c in own_combo:
            assert 0 <= c <= 51, f"card id {c} out of range 0..51 — key encoding assumes 2 digits"
        combo_digits = "".join(f"{c:02d}" for c in own_combo)
        return f"{combo_digits}|{actions}"
