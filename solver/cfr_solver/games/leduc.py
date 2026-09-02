"""Leduc Hold'em — verification benchmark #2.

Standard next-step-up benchmark in the CFR research literature (Southey et
al., 2005; used again as the Monte Carlo CFR benchmark in Lanctot et al.,
2009; OpenSpiel ships `leduc_poker` as a canonical reference
implementation). Much closer to real poker than Kuhn Poker: two betting
rounds separated by a public board card, instead of one.

Rules used by this implementation (recorded here precisely since "Leduc
Hold'em" is a family of closely related games in the literature, not a
single frozen spec — this exact configuration is what `BENCHMARKS.md`'s
recorded convergence numbers apply to):

- 6-card deck: ranks J/Q/K, two copies (suits) of each. Each player antes 1
  and is dealt one private card.
- Round 1 ("preflop"): fixed bet size 2. Round 2 ("postflop", after one
  public board card is dealt): fixed bet size 4.
- Each round allows at most one bet and one raise (i.e. at most 2 wager
  actions total per round — betting is "capped" after a single raise, a
  common limit-poker convention). Player 0 acts first in both rounds (this
  toy benchmark does not model a real dealer button).
- Showdown: pairing the board beats any non-pair; otherwise higher private
  card rank wins; identical rank with neither pairing the board splits the
  pot.

Action encoding: "x" = check, "b" = bet or raise (whichever is legal), "c"
= call, "f" = fold. `History` is
`(card0, card1, board, round1_actions, round2_actions)` where card/board
values are physical card ids 0..5 (rank = id // 2) so the deck is dealt
without replacement, and `None` means "not yet dealt".
"""

from __future__ import annotations

from cfr_solver.games.game import Action, Game, History

RANKS = ("J", "Q", "K")
ROUND1_BET_SIZE = 2.0
ROUND2_BET_SIZE = 4.0
ANTE = 1.0
MAX_WAGERS_PER_ROUND = 2  # one bet + one raise, then capped


def _round_done(tokens: str) -> bool:
    return tokens == "xx" or (bool(tokens) and tokens[-1] in ("c", "f"))


def _round_folded(tokens: str) -> bool:
    return bool(tokens) and tokens[-1] == "f"


def _legal_for_tokens(tokens: str) -> list[Action]:
    if tokens == "" or tokens[-1] == "x":
        return ["x", "b"]
    if tokens[-1] == "b":
        if tokens.count("b") < MAX_WAGERS_PER_ROUND:
            return ["f", "c", "b"]
        return ["f", "c"]
    raise ValueError(f"legal_actions called on a completed round: {tokens!r}")


def _simulate_round(tokens: str, bet_size: float) -> tuple[list[float], int | None]:
    """Chips each player put into the pot this round, and who folded (if anyone)."""
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


def _payoffs_from_fold(total_contrib: list[float], folder: int) -> list[float]:
    pot = sum(total_contrib)
    winner = 1 - folder
    result = [0.0, 0.0]
    result[winner] = pot - total_contrib[winner]
    result[folder] = -total_contrib[folder]
    return result


class LeducHoldem(Game):
    @property
    def num_players(self) -> int:
        return 2

    def new_initial_history(self) -> History:
        return (None, None, None, "", "")

    def is_chance_node(self, history: History) -> bool:
        card0, card1, board, r1, _r2 = history
        if card0 is None or card1 is None:
            return True
        return _round_done(r1) and not _round_folded(r1) and board is None

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        card0, card1, board, _r1, _r2 = history
        if card0 is None:
            return [(str(c), 1 / 6) for c in range(6)]
        if card1 is None:
            remaining = [c for c in range(6) if c != card0]
            return [(str(c), 1 / 5) for c in remaining]
        remaining = [c for c in range(6) if c not in (card0, card1)]
        return [(str(c), 1 / 4) for c in remaining]

    def next_history(self, history: History, action: Action) -> History:
        card0, card1, board, r1, r2 = history
        if card0 is None:
            return (int(action), card1, board, r1, r2)
        if card1 is None:
            return (card0, int(action), board, r1, r2)
        if _round_done(r1) and not _round_folded(r1) and board is None:
            return (card0, card1, int(action), r1, r2)
        if not _round_done(r1):
            return (card0, card1, board, r1 + action, r2)
        return (card0, card1, board, r1, r2 + action)

    def is_terminal(self, history: History) -> bool:
        card0, card1, board, r1, r2 = history
        if card0 is None or card1 is None:
            return False
        if not _round_done(r1):
            return False
        if _round_folded(r1):
            return True
        if board is None:
            return False
        return _round_done(r2)

    def current_player(self, history: History) -> int:
        _card0, _card1, _board, r1, r2 = history
        if not _round_done(r1):
            return len(r1) % 2
        return len(r2) % 2

    def legal_actions(self, history: History) -> list[Action]:
        _card0, _card1, _board, r1, r2 = history
        tokens = r1 if not _round_done(r1) else r2
        return _legal_for_tokens(tokens)

    def returns(self, history: History) -> list[float]:
        card0, card1, board, r1, r2 = history
        contrib1, folder1 = _simulate_round(r1, ROUND1_BET_SIZE)

        if folder1 is not None:
            total = [ANTE + contrib1[0], ANTE + contrib1[1]]
            return _payoffs_from_fold(total, folder1)

        contrib2, folder2 = _simulate_round(r2, ROUND2_BET_SIZE)
        total = [ANTE + contrib1[0] + contrib2[0], ANTE + contrib1[1] + contrib2[1]]

        if folder2 is not None:
            return _payoffs_from_fold(total, folder2)

        rank0, rank1, board_rank = card0 // 2, card1 // 2, board // 2
        pair0 = rank0 == board_rank
        pair1 = rank1 == board_rank
        pot = sum(total)

        if pair0 and not pair1:
            winner: int | None = 0
        elif pair1 and not pair0:
            winner = 1
        elif rank0 > rank1:
            winner = 0
        elif rank1 > rank0:
            winner = 1
        else:
            winner = None  # identical rank, neither pairs the board -> split

        if winner is None:
            half = pot / 2.0
            return [half - total[0], half - total[1]]
        result = [0.0, 0.0]
        result[winner] = pot - total[winner]
        result[1 - winner] = -total[1 - winner]
        return result

    def information_set_key(self, history: History, player: int) -> str:
        card0, card1, board, r1, r2 = history
        own_card = card0 if player == 0 else card1
        own_rank = RANKS[own_card // 2]
        board_str = RANKS[board // 2] if board is not None else "-"
        return f"{own_rank}|{board_str}|{r1}|{r2}"
