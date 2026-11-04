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
Each street reuses the same check/bet/call/fold/raise action encoding
(`"x"`/`"1".."4"`/`"c"`/`"f"`), capped per street by `max_wagers_per_round`.
Showdown (reached only if neither street-ending fold happens) evaluates the
best 5-card hand out of the 2 hole + 5 board cards.

Bet/raise sizing is pot-relative (not a fixed chip amount): `"1".."4"` each
select one fraction from `bet_fractions` (default: 1/3, 1/2, 2/3 pot, and a
1.5x-pot overbet), computed against the pot AS OF that decision — the
standard "X% pot" sizing used by real solvers, not a flat bb amount. The
same fraction grid is offered for every bet AND every raise, on every
street (no separate per-street sizing).

Player 0 always acts first on every street (`current_player` is
`len(tokens) % 2`, and every street's tokens start fresh at `""`). This is
a real positional fact, not an arbitrary simplification: in a heads-up pot
the out-of-position player acts first on every post-flop street, and the
in-position player acts last — see AGENTS.md's "ポジションの前後判定" note.
**Callers must assign the out-of-position player's range to
`hero_range_notation` (player 0) and the in-position player's range to
`villain_range_notation` (player 1)**, regardless of which one the caller
is actually trying to teach a strategy for — e.g. for a BTN-open/BB-call
single-raised pot, BB is out of position and must be `hero_range_notation`
even though the app teaches BTN's strategy; get this backwards and every
exported frequency models the wrong player acting first on every street.
"""

from __future__ import annotations

from collections import Counter
from functools import lru_cache

from cfr_solver import _native
from cfr_solver.games.game import Action, Game, History
from cfr_solver.poker.cards import DECK, evaluate_best_hand, rank_of, suit_of
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


# One character per pot-fraction in `bet_fractions` — index into the tuple.
_BET_TOKENS = "1234"


@lru_cache(maxsize=None)
def _legal_for_tokens(tokens: str, max_wagers: int, n_sizes: int) -> tuple[Action, ...]:
    bet_tokens = _BET_TOKENS[:n_sizes]
    if tokens == "" or tokens[-1] == "x":
        return ("x", *bet_tokens)
    if tokens[-1] in _BET_TOKENS:
        n_bets = sum(1 for ch in tokens if ch in _BET_TOKENS)
        if n_bets < max_wagers:
            return ("f", "c", *bet_tokens)
        return ("f", "c")
    raise ValueError(f"legal_actions called on a completed round: {tokens!r}")


@lru_cache(maxsize=None)
def _simulate_round(
    tokens: str, pot_before: float, bet_fractions: tuple[float, ...]
) -> tuple[tuple[float, float], int | None, float]:
    """Simulate one street's betting. Bet/raise sizes are a fraction of the
    pot AS OF that action (standard "X% pot" sizing): `to_call` is added to
    the pot first, then the chosen fraction of THAT pot is the raise on top
    — so the first bet in a round (`to_call == 0`) is simply
    `fraction * pot_before`, and a raise is `to_call + fraction * (pot so
    far + to_call)`. Returns ((contrib0, contrib1), folder_or_None,
    pot_after_this_round) — `pot_after_this_round` feeds the next street's
    `pot_before` (or, on a fold, is irrelevant and omitted by the caller)."""
    contrib = [0.0, 0.0]
    level = 0.0
    actor = 0
    for ch in tokens:
        if ch == "c":
            contrib[actor] = level
        elif ch == "f":
            return (contrib[0], contrib[1]), actor, pot_before + contrib[0] + contrib[1]
        elif ch in _BET_TOKENS:
            fraction = bet_fractions[_BET_TOKENS.index(ch)]
            to_call = level - contrib[actor]
            pot_if_called = pot_before + contrib[0] + contrib[1] + to_call
            contrib[actor] += to_call + fraction * pot_if_called
            level = contrib[actor]
        actor = 1 - actor
    return (contrib[0], contrib[1]), None, pot_before + contrib[0] + contrib[1]


@lru_cache(maxsize=None)
def _active_round_for(
    board: tuple[int, ...], flop_a: str, turn_a: str, river_a: str
) -> tuple[str, int] | None:
    """Module-level, cached twin of `PostflopSubgame._active_round` — identical
    logic, just pulled out of the class so `lru_cache` can key on the
    (board, action-strings) tuple directly instead of needing an
    instance-aware cache."""
    if len(board) == 3:
        return (flop_a, 0) if not _round_done(flop_a) else None
    if len(board) == 4:
        return (turn_a, 1) if not _round_done(turn_a) else None
    return (river_a, 2) if not _round_done(river_a) else None


@lru_cache(maxsize=None)
def _card_digits(cards: tuple[int, ...]) -> str:
    """2-zero-padded-digits-per-card encoding used by `information_set_key`
    (see that method's docstring). Own-combo and board tuples repeat across
    every history that shares them (same combo dealt to many boards, same
    board reached by many combos), so caching this small, pure formatting
    step avoids re-running `str.join`/`f"{c:02d}"` from scratch on every one
    of the many information-set-key calls that share a combo or a board."""
    return "".join(f"{c:02d}" for c in cards)


@lru_cache(maxsize=None)
def _canonical_suit_map(visible: tuple[int, ...]) -> tuple[int, int, int, int]:
    """Suit isomorphism: a deterministic relabeling of the 4 suits, computed
    purely from the cards visible to ONE player at one information set (their
    own hole cards + the board — never the opponent's hidden cards, which
    this player can't see and whose identity can't legally factor into their
    own strategy). `cards.py`'s module docstring already states "suit
    identity only matters for flushes/blockers, never displayed": two deals
    related by a global suit permutation (e.g. swap every heart and diamond,
    everywhere, consistently) are strategically identical — every
    not-yet-dealt card is still drawn uniformly over the remaining deck, and
    `evaluate_best_hand` only cares about rank matches and same-suit counts,
    never which of the 4 labels a suit happens to have. Relabeling suits to
    a canonical order before building the information-set key merges these
    genuinely-identical situations into one shared CFR node instead of
    training each one as if it were different — an EXACT symmetry
    reduction, not the card-bucketing approximation `games/flop_subgame.py`
    explicitly disclaims (no hand is ever grouped with a *different* hand;
    only the meaningless suit label is normalized away). Hole-card
    suitedness and flush blockers remain fully distinguished, because the
    map is a bijection: two cards that share a suit before canonicalization
    still share a suit after it, and two cards of different suits still map
    to different canonical suits.

    Why this matters in practice: a real production run on GCP (2026-10-27,
    see `BENCHMARKS.md`) found this game's information-set count growing
    with no sign of plateauing anywhere near the target iteration count —
    exactly the kind of blow-up suit isomorphism exists to prevent, and the
    standard, lossless reduction production solvers (the kind `docs/` already
    compares this project's output against) rely on.

    `visible` must be exactly `(*own_combo, *board)` for ONE player (never
    both players' hole cards mixed together). Returns a 4-tuple: `result[old
    _suit] = canonical_suit`.
    """

    def signature(s: int) -> tuple[int, ...]:
        return tuple(sorted((rank_of(c) for c in visible if suit_of(c) == s), reverse=True))

    order = sorted(range(4), key=lambda s: (len(signature(s)), signature(s)), reverse=True)
    canonical = [0, 0, 0, 0]
    for canon_suit, old_suit in enumerate(order):
        canonical[old_suit] = canon_suit
    return (canonical[0], canonical[1], canonical[2], canonical[3])


def _canonicalize_cards(
    cards: tuple[int, ...], suit_map: tuple[int, int, int, int]
) -> tuple[int, ...]:
    return tuple(rank_of(c) * 4 + suit_map[suit_of(c)] for c in cards)


@lru_cache(maxsize=None)
def _hand_strength_bucket(own_combo: tuple[int, ...], board: tuple[int, ...]) -> tuple[int, int]:
    """A coarse hand-strength signal — this hand's category (high card ..
    straight flush) and top kicker rank, evaluated against the current
    board (`evaluate_best_hand`, already the hot-path evaluator used at
    showdown) — used in place of the exact 2 hole cards when
    `hand_strength_bucket=True`.

    **Unlike `_canonical_suit_map`, this IS a real approximation, not an
    exact symmetry reduction.** Two different combos that make the same
    category with the same top kicker collapse onto the same CFR node even
    though their true equity can differ (e.g. two top-pair hands with the
    same kicker but different side cards, or a made hand vs a draw that
    happens to share a category/kicker on an earlier street). This trades
    precision for a much larger cut in information-set count than suit
    isomorphism alone achieved in practice (measured 2026-10-27/-30, see
    `BENCHMARKS.md`: suit isomorphism alone gave 0%-5.5% reduction across
    real production boards, far short of what reaching 12M iterations
    needs). AGENTS.md rule 1 (never present an approximate number as exact)
    means any export produced with this enabled must say so in its "note"
    field — this is the same honesty obligation `solve_srp_btn_bb.py`
    already applies to "approximate solve ... at the stated iterations".

    Opt-in, off by default, so existing exact-key fixtures/tests are
    untouched.
    """
    category, *kickers = evaluate_best_hand(list(own_combo) + list(board))
    return (category, kickers[0] if kickers else -1)


@lru_cache(maxsize=None)
def _card_texture_delta(new_card: int, prior_board: tuple[int, ...]) -> tuple[int, int]:
    """How one newly-dealt board card (turn, or river) changes the BOARD's
    texture relative to the board before it — independent of either
    player's hole cards. Two flags: `(pairs_board, advances_flush)`.

    This exists for the same reason `_hand_strength_bucket` does (a real
    approximation, see that function's docstring for the honesty
    obligation), but targets the OTHER dimension of this game's
    information-set blow-up: `hand_strength_bucket` only compresses the 2
    hole cards, so a fixed flop still gets a fresh, fully-distinct
    information set for every one of the ~1,892 possible (turn, river) card
    pairs the training walk samples — the user's own framing: "pairs the
    board or not, advances a flush or not" is exactly the board-level
    analogue of `_hand_strength_bucket`'s "made a hand or not" for hole
    cards, and is already the same kind of texture classification
    `solve_srp_btn_bb.py`'s own readout uses to pick representative
    turn/river cards (`_blank_card`/`_overcard`/`_texture_change_card`) —
    this just applies that idea to every card the TRAINING walk sees,
    not only the few representative ones read out afterward.
    """
    prior_ranks = {rank_of(c) for c in prior_board}
    pairs_board = 1 if rank_of(new_card) in prior_ranks else 0
    suit_counts = Counter(suit_of(c) for c in prior_board)
    dominant_suit, dominant_count = (
        suit_counts.most_common(1)[0] if suit_counts else (None, 0)
    )
    advances_flush = 1 if dominant_count >= 2 and suit_of(new_card) == dominant_suit else 0
    return (pairs_board, advances_flush)


def _board_texture_key(board: tuple[int, ...]) -> str:
    """The flop's 3 cards stay literal (always the same single fixed flop
    within one `solve_board()` call — no multiplicity to compress there);
    the turn and river (if dealt) are each replaced by their
    `_card_texture_delta` relative to the board as it stood before them."""
    flop_digits = _card_digits(board[:3])
    parts = [flop_digits]
    prior = board[:3]
    for extra in board[3:]:
        pairs, flush = _card_texture_delta(extra, prior)
        parts.append(f"t{pairs}{flush}")
        prior = prior + (extra,)
    return "".join(parts)


def _payoffs_from_fold(total_contrib: list[float], folder: int) -> list[float]:
    pot = sum(total_contrib)
    winner = 1 - folder
    result = [0.0, 0.0]
    result[winner] = pot - total_contrib[winner]
    result[folder] = -total_contrib[folder]
    return result


class PostflopSubgame(Game):
    """Player 0 ("hero") acts first on every street. This is a real
    positional fact, not an arbitrary simplification — see the module
    docstring's note on assigning the out-of-position player to player 0.

    `suit_isomorphism=True` relabels suits to a canonical order before
    building each information-set key (see `_canonical_suit_map`'s
    docstring) — an exact, lossless symmetry reduction, off by default so
    existing fixtures/tests keep their frozen raw-card keys unchanged.

    `hand_strength_bucket=True` additionally collapses the exact 2 hole
    cards to (hand category, top kicker) against the current board (see
    `_hand_strength_bucket`'s docstring) — unlike `suit_isomorphism`, this
    IS a real approximation, not a lossless reduction; also off by default.

    `board_texture_bucket=True` is the board-side analogue: each dealt
    turn/river card is replaced by its texture delta (pairs the board? /
    advances a flush?) relative to the board before it, instead of its
    exact identity (see `_board_texture_key`'s docstring). Also a real
    approximation, also off by default, and supersedes `suit_isomorphism`'s
    board canonicalization when both are enabled.
    """

    def __init__(
        self,
        flop_board: list[int],
        hero_range_notation: str,
        villain_range_notation: str,
        *,
        preflop_contrib: tuple[float, float] = (2.5, 2.5),
        bet_fractions: tuple[float, ...] = (1 / 3, 1 / 2, 2 / 3, 1.5),
        max_wagers_per_round: int = 1,
        suit_isomorphism: bool = False,
        hand_strength_bucket: bool = False,
        board_texture_bucket: bool = False,
    ) -> None:
        if len(flop_board) != 3:
            raise ValueError("PostflopSubgame expects exactly a 3-card flop board")
        if len(bet_fractions) > len(_BET_TOKENS):
            raise ValueError(f"at most {len(_BET_TOKENS)} bet_fractions are supported")
        self.flop_board: tuple[int, ...] = tuple(flop_board)
        blocked = set(flop_board)
        self.hero_combos: list[Combo] = range_combos(expand_range(hero_range_notation), blocked)
        self.villain_combos: list[Combo] = range_combos(
            expand_range(villain_range_notation), blocked
        )
        if not self.hero_combos or not self.villain_combos:
            raise ValueError("a range produced zero combos after removing the flop board")
        self.preflop_contrib = preflop_contrib
        self.bet_fractions = bet_fractions
        self.max_wagers_per_round = max_wagers_per_round
        self.suit_isomorphism = suit_isomorphism
        self.hand_strength_bucket = hand_strength_bucket
        self.board_texture_bucket = board_texture_bucket
        self._equity_cache = _native.EquityCache()

    @property
    def num_players(self) -> int:
        return 2

    def new_initial_history(self) -> History:
        return (None, None, self.flop_board, "", "", "")

    # -- street helpers -----------------------------------------------

    def _active_round(self, board: tuple[int, ...], flop_a: str, turn_a: str, river_a: str):
        """(tokens, street_index) for whichever round is currently being bet,
        or None if we're between streets / at showdown. Delegates to the
        cached module-level `_active_round_for` (same logic, just memoized —
        see that function's docstring)."""
        return _active_round_for(board, flop_a, turn_a, river_a)

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
        tokens, _street = active
        return len(tokens) % 2

    def legal_actions(self, history: History) -> list[Action]:
        _hero_combo, _villain_combo, board, flop_a, turn_a, river_a = history
        active = self._active_round(board, flop_a, turn_a, river_a)
        assert active is not None
        tokens, _street = active
        # `_legal_for_tokens` is `lru_cache`d and returns a shared tuple —
        # `list(...)` here gives every caller its own fresh list (matching
        # the pre-caching behavior exactly) while still skipping the cached
        # function's branching on a repeat (tokens, max_wagers, n_sizes) pair.
        return list(
            _legal_for_tokens(tokens, self.max_wagers_per_round, len(self.bet_fractions))
        )

    def returns(self, history: History) -> list[float]:
        hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
        pot0 = self.preflop_contrib[0] + self.preflop_contrib[1]

        contrib_flop, folder_flop, pot_after_flop = _simulate_round(
            flop_a, pot0, self.bet_fractions
        )
        if folder_flop is not None:
            total = [self.preflop_contrib[i] + contrib_flop[i] for i in (0, 1)]
            return _payoffs_from_fold(total, folder_flop)

        contrib_turn, folder_turn, pot_after_turn = _simulate_round(
            turn_a, pot_after_flop, self.bet_fractions
        )
        if folder_turn is not None:
            total = [
                self.preflop_contrib[i] + contrib_flop[i] + contrib_turn[i] for i in (0, 1)
            ]
            return _payoffs_from_fold(total, folder_turn)

        contrib_river, folder_river, _pot_after_river = _simulate_round(
            river_a, pot_after_turn, self.bet_fractions
        )
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
        return self._equity_cache.equity(hero_combo, villain_combo, board)

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
        if self.hand_strength_bucket:
            # See `_hand_strength_bucket`'s docstring: a REAL approximation
            # (unlike suit isomorphism below) — collapses the exact 2 hole
            # cards down to (hand category, top kicker) against the current
            # board. Suit canonicalization of the board still applies
            # separately below if also enabled (hand category/kicker are
            # suit-invariant either way, so the order doesn't matter).
            category, kicker = _hand_strength_bucket(own_combo, board)
            combo_digits = f"b{category}{kicker + 1:02d}"
        else:
            combo_digits = None
        if self.board_texture_bucket:
            # See `_board_texture_key`'s docstring: a REAL approximation,
            # the board-side analogue of `hand_strength_bucket` — replaces
            # each dealt turn/river card with its texture delta instead of
            # its exact identity. Supersedes `suit_isomorphism`'s board
            # canonicalization when both are on (the delta already discards
            # exact suit identity for turn/river; the flop's 3 cards stay
            # literal either way, and suit-canonicalizing a single fixed
            # flop has nothing to merge it with within one solve).
            board_digits = _board_texture_key(board)
        elif self.suit_isomorphism:
            # See `_canonical_suit_map`'s docstring: merges strategically
            # identical suit-permuted deals into one CFR node (exact, not an
            # approximation) — computed from this player's own visible cards
            # only, never the opponent's.
            suit_map = _canonical_suit_map((*own_combo, *board))
            own_combo = _canonicalize_cards(own_combo, suit_map) if combo_digits is None else own_combo
            board_digits = _card_digits(_canonicalize_cards(board, suit_map))
        else:
            board_digits = None
        # `_card_digits` is `lru_cache`d: the same `own_combo` and the same
        # `board` each recur across many information-set-key calls (every
        # other combo pair sharing this board, every later street reusing
        # this same dealt combo), so this reuses the formatted digit string
        # instead of re-running `str.join`/`f"{c:02d}"` from scratch each
        # time (see module-level docstring above `_card_digits`).
        if combo_digits is None:
            combo_digits = _card_digits(own_combo)
        if board_digits is None:
            board_digits = _card_digits(board)
        return f"{combo_digits}{board_digits}|{flop_a}|{turn_a}|{river_a}"
