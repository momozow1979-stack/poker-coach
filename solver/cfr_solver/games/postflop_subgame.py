"""A real heads-up postflop hand played out across all three remaining
streets — flop, turn, river — each with its own betting round, connected by
real chance-dealt cards. This is the structural fix `flop_subgame.py`
deliberately deferred: that module solves exactly one betting round in
isolation, but a street's correct strategy depends on the EV of every
possible continuation, most of which end (by fold) before ever reaching a
later street's showdown. CFR itself has always computed a strategy at every
information set, not just an aggregate number — this is exactly what
Leduc Hold'em's two-street, fold-anywhere structure already exercises (see
`games/leduc.py`, verified in `BENCHMARKS.md`). What was missing was a real
52-card game with that same connected, multi-street shape; this module is
that game.

History = `(hero_combo, villain_combo, board, flop_actions, turn_actions,
river_actions)`. `board` starts as the given 3-card flop and grows to 4
cards (turn dealt by chance, once the flop round ends without a fold) and
then 5 (river dealt by chance, once the turn round ends without a fold).
Each street reuses the same bet/call/fold/raise action encoding as
`flop_subgame.py` (`"x"`/`"b"`/`"c"`/`"f"`), independently sized and capped
per street. Showdown (reached only if neither street-ending fold happens)
evaluates the best 5-card hand out of the 2 hole + 5 board cards.
"""

from __future__ import annotations

from functools import lru_cache

from cfr_solver.games.game import Action, Game, History
from cfr_solver.poker.cards import DECK, evaluate_best_hand
from cfr_solver.poker.combos import Combo, range_combos
from cfr_solver.poker.range_notation import expand as expand_range

# `exploitability.best_response_value`'s `walk` visits the SAME history many
# times over (once per policy-iteration sweep, for both `actual_value` and
# both players' best responses), and the exact same (board, flop_a, turn_a,
# river_a) state recurs identically across every one of a spot's hero/villain
# combo pairs — the round/street bookkeeping below never depends on which
# combo was dealt. Profiling `exploitability()` on the AA-vs-KK spot
# (`BENCHMARKS.md`, "高速ハンド評価器...") found ~100s spent redundantly
# re-deriving this same "what street, whose turn, is this round over" answer
# from scratch on every single visit. All of the functions below are pure
# functions of small, bounded-cardinality, hashable inputs (a handful of
# action-token strings and board tuples per spot) — an ideal `lru_cache` fit:
# caching turns the repeat visits into O(1) dict lookups without changing a
# single branch of the original logic (verified in
# `tests/test_postflop_subgame_optimization_regression.py` against frozen
# naive/uncached reference copies of each function, over every reachable
# input).


@lru_cache(maxsize=None)
def _round_done(tokens: str) -> bool:
    return tokens == "xx" or (bool(tokens) and tokens[-1] in ("c", "f"))


@lru_cache(maxsize=None)
def _round_folded(tokens: str) -> bool:
    return bool(tokens) and tokens[-1] == "f"


@lru_cache(maxsize=None)
def _legal_for_tokens(tokens: str, max_wagers: int) -> tuple[Action, ...]:
    if tokens == "" or tokens[-1] == "x":
        return ("x", "b")
    if tokens[-1] == "b":
        if tokens.count("b") < max_wagers:
            return ("f", "c", "b")
        return ("f", "c")
    raise ValueError(f"legal_actions called on a completed round: {tokens!r}")


@lru_cache(maxsize=None)
def _simulate_round(tokens: str, bet_size: float) -> tuple[tuple[float, float], int | None]:
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
            return (contrib[0], contrib[1]), actor
        actor = 1 - actor
    return (contrib[0], contrib[1]), None


@lru_cache(maxsize=None)
def _active_round_for(
    board: tuple[int, ...],
    flop_a: str,
    turn_a: str,
    river_a: str,
    bet_sizes: tuple[float, float, float],
) -> tuple[str, float, int] | None:
    """Module-level, cached twin of `PostflopSubgame._active_round` — identical
    logic, just pulled out of the class so `lru_cache` can key on the
    (board, action-strings, bet_sizes) tuple directly instead of needing an
    instance-aware cache. `bet_sizes` is passed through so this stays a pure
    function shareable across every `PostflopSubgame` instance with the same
    bet sizing (harmless: results depend only on the arguments, never on
    which instance asked)."""
    if len(board) == 3:
        return (flop_a, bet_sizes[0], 0) if not _round_done(flop_a) else None
    if len(board) == 4:
        return (turn_a, bet_sizes[1], 1) if not _round_done(turn_a) else None
    return (river_a, bet_sizes[2], 2) if not _round_done(river_a) else None


@lru_cache(maxsize=None)
def _card_digits(cards: tuple[int, ...]) -> str:
    """2-zero-padded-digits-per-card encoding used by `information_set_key`
    (see that method's docstring). Own-combo and board tuples repeat across
    every history that shares them (same combo dealt to many boards, same
    board reached by many combos), so caching this small, pure formatting
    step avoids re-running `str.join`/`f"{c:02d}"` from scratch on every one
    of the many information-set-key calls that share a combo or a board."""
    return "".join(f"{c:02d}" for c in cards)


def _payoffs_from_fold(total_contrib: list[float], folder: int) -> list[float]:
    pot = sum(total_contrib)
    winner = 1 - folder
    result = [0.0, 0.0]
    result[winner] = pot - total_contrib[winner]
    result[folder] = -total_contrib[folder]
    return result


class PostflopSubgame(Game):
    """Player 0 ("hero") acts first on every street — the same simplification
    `flop_subgame.py` makes (real position depends on the exact preflop
    action; this benchmark does not model who was actually last to act).
    """

    def __init__(
        self,
        flop_board: list[int],
        hero_range_notation: str,
        villain_range_notation: str,
        *,
        preflop_contrib: tuple[float, float] = (2.5, 2.5),
        bet_sizes: tuple[float, float, float] = (2.5, 5.0, 7.5),
        max_wagers_per_round: int = 1,
    ) -> None:
        if len(flop_board) != 3:
            raise ValueError("PostflopSubgame expects exactly a 3-card flop board")
        self.flop_board: tuple[int, ...] = tuple(flop_board)
        blocked = set(flop_board)
        self.hero_combos: list[Combo] = range_combos(expand_range(hero_range_notation), blocked)
        self.villain_combos: list[Combo] = range_combos(
            expand_range(villain_range_notation), blocked
        )
        if not self.hero_combos or not self.villain_combos:
            raise ValueError("a range produced zero combos after removing the flop board")
        self.preflop_contrib = preflop_contrib
        self.bet_sizes = bet_sizes  # (flop, turn, river)
        self.max_wagers_per_round = max_wagers_per_round
        self._equity_cache: dict[tuple[Combo, Combo, tuple[int, ...]], float] = {}

    @property
    def num_players(self) -> int:
        return 2

    def new_initial_history(self) -> History:
        return (None, None, self.flop_board, "", "", "")

    # -- street helpers -----------------------------------------------

    def _active_round(self, board: tuple[int, ...], flop_a: str, turn_a: str, river_a: str):
        """(tokens, bet_size, street_index) for whichever round is currently
        being bet, or None if we're between streets / at showdown. Delegates
        to the cached module-level `_active_round_for` (same logic, just
        memoized — see that function's docstring)."""
        return _active_round_for(board, flop_a, turn_a, river_a, self.bet_sizes)

    # -- Game interface -------------------------------------------------

    def is_chance_node(self, history: History) -> bool:
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
        if hero_combo is None or villain_combo is None:
            return True
        if len(board) == 3 and _round_done(flop_a) and not _round_folded(flop_a):
            return True
        if len(board) == 4 and _round_done(turn_a) and not _round_folded(turn_a):
            return True
        return False

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        hero_combo, villain_combo, board, _flop_a, _turn_a, _river_a = history
        if hero_combo is None:
            n = len(self.hero_combos)
            return [(str(i), 1 / n) for i in range(n)]
        if villain_combo is None:
            live = [
                i
                for i, combo in enumerate(self.villain_combos)
                if not (set(combo) & set(hero_combo))
            ]
            if not live:
                raise RuntimeError("every villain combo clashes with hero's dealt combo")
            return [(str(i), 1 / len(live)) for i in live]
        # turn or river card
        used = set(board) | set(hero_combo) | set(villain_combo)
        remaining = [c for c in DECK if c not in used]
        return [(str(c), 1 / len(remaining)) for c in remaining]

    def next_history(self, history: History, action: Action) -> History:
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
        if hero_combo is None:
            return (self.hero_combos[int(action)], villain_combo, board, flop_a, turn_a, river_a)
        if villain_combo is None:
            return (hero_combo, self.villain_combos[int(action)], board, flop_a, turn_a, river_a)
        if len(board) == 3 and _round_done(flop_a) and not _round_folded(flop_a):
            return (hero_combo, villain_combo, board + (int(action),), flop_a, turn_a, river_a)
        if len(board) == 4 and _round_done(turn_a) and not _round_folded(turn_a):
            return (hero_combo, villain_combo, board + (int(action),), flop_a, turn_a, river_a)
        if len(board) == 3:
            return (hero_combo, villain_combo, board, flop_a + action, turn_a, river_a)
        if len(board) == 4:
            return (hero_combo, villain_combo, board, flop_a, turn_a + action, river_a)
        return (hero_combo, villain_combo, board, flop_a, turn_a, river_a + action)

    def is_terminal(self, history: History) -> bool:
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
        if hero_combo is None or villain_combo is None:
            return False
        if len(board) == 3:
            return _round_done(flop_a) and _round_folded(flop_a)
        if len(board) == 4:
            return _round_done(turn_a) and _round_folded(turn_a)
        return _round_done(river_a)

    def current_player(self, history: History) -> int:
        _hero_combo, _villain_combo, board, flop_a, turn_a, river_a = history
        active = self._active_round(board, flop_a, turn_a, river_a)
        assert active is not None
        tokens, _bet_size, _street = active
        return len(tokens) % 2

    def legal_actions(self, history: History) -> list[Action]:
        _hero_combo, _villain_combo, board, flop_a, turn_a, river_a = history
        active = self._active_round(board, flop_a, turn_a, river_a)
        assert active is not None
        tokens, _bet_size, _street = active
        # `_legal_for_tokens` is `lru_cache`d and returns a shared tuple —
        # `list(...)` here gives every caller its own fresh list (matching
        # the pre-caching behavior exactly) while still skipping the cached
        # function's branching on a repeat (tokens, max_wagers) pair.
        return list(_legal_for_tokens(tokens, self.max_wagers_per_round))

    def returns(self, history: History) -> list[float]:
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history

        contrib_flop, folder_flop = _simulate_round(flop_a, self.bet_sizes[0])
        if folder_flop is not None:
            total = [self.preflop_contrib[i] + contrib_flop[i] for i in (0, 1)]
            return _payoffs_from_fold(total, folder_flop)

        contrib_turn, folder_turn = _simulate_round(turn_a, self.bet_sizes[1])
        if folder_turn is not None:
            total = [
                self.preflop_contrib[i] + contrib_flop[i] + contrib_turn[i] for i in (0, 1)
            ]
            return _payoffs_from_fold(total, folder_turn)

        contrib_river, folder_river = _simulate_round(river_a, self.bet_sizes[2])
        total = [
            self.preflop_contrib[i] + contrib_flop[i] + contrib_turn[i] + contrib_river[i]
            for i in (0, 1)
        ]
        if folder_river is not None:
            return _payoffs_from_fold(total, folder_river)

        equity = self._equity(hero_combo, villain_combo, board)
        pot = sum(total)
        return [equity * pot - total[0], (1 - equity) * pot - total[1]]

    def _equity(self, hero_combo: Combo, villain_combo: Combo, board: tuple[int, ...]) -> float:
        key = (hero_combo, villain_combo, board)
        cached = self._equity_cache.get(key)
        if cached is not None:
            return cached
        hero_rank = evaluate_best_hand(list(hero_combo) + list(board))
        villain_rank = evaluate_best_hand(list(villain_combo) + list(board))
        if hero_rank > villain_rank:
            equity = 1.0
        elif hero_rank < villain_rank:
            equity = 0.0
        else:
            equity = 0.5
        self._equity_cache[key] = equity
        return equity

    def information_set_key(self, history: History, player: int) -> str:
        """A compact, injective encoding — 2 zero-padded decimal digits per
        card id (ids are 0..51, so 2 digits always suffice) instead of
        Python's verbose tuple `repr()` (parens/commas/spaces). `|`
        separators are kept between the three action-history fields (never
        used inside a digit run or an action string) so two different
        action histories can never concatenate into the same string — e.g.
        without them, flop_a="xb" + turn_a="" would collide with
        flop_a="x" + turn_a="b". This changes what the string looks like,
        not what information it encodes (`BENCHMARKS.md`, "情報集合の保存方式").
        """
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
        own_combo = hero_combo if player == 0 else villain_combo
        for c in (*own_combo, *board):
            assert 0 <= c <= 51, f"card id {c} out of range 0..51 — key encoding assumes 2 digits"
        # `_card_digits` is `lru_cache`d: the same `own_combo` and the same
        # `board` each recur across many information-set-key calls (every
        # other combo pair sharing this board, every later street reusing
        # this same dealt combo), so this reuses the formatted digit string
        # instead of re-running `str.join`/`f"{c:02d}"` from scratch each
        # time (see module-level docstring above `_card_digits`).
        combo_digits = _card_digits(own_combo)
        board_digits = _card_digits(board)
        return f"{combo_digits}{board_digits}|{flop_a}|{turn_a}|{river_a}"
