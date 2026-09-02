"""Kuhn Poker — verification benchmark #1.

3-card deck (J, Q, K), each player antes 1. One private card each, one round
of betting with a single bet size of 1. Standard textbook game (Kuhn, 1950),
used as the introductory example in the original CFR paper (Zinkevich et
al., 2007). Its Nash equilibrium value is known exactly (-1/18 for the
first-to-act player), which is what `tests/test_kuhn_equilibrium.py` checks
this implementation's trained strategy against.

Action encoding follows the standard convention used throughout the CFR
literature: every decision is between "p" (pass — check if not facing a
bet, fold if facing one) and "b" (bet — bet if not facing one, call if
facing one). This makes terminal detection a simple pattern match on the
action string: "pp", "bp", "bb", "pbp", "pbb".

History = (card0: int | None, card1: int | None, actions: str)
where card ranks are 0=J, 1=Q, 2=K (higher wins) and `None` means "not yet
dealt" (only during the two chance nodes at the start of a hand).
"""

from __future__ import annotations

from cfr_solver.games.game import Action, Game, History

RANKS = ("J", "Q", "K")  # index doubles as strength; higher wins
_TERMINAL_ACTIONS = {"pp", "bp", "bb", "pbp", "pbb"}


class KuhnPoker(Game):
    @property
    def num_players(self) -> int:
        return 2

    def new_initial_history(self) -> History:
        return (None, None, "")

    def is_chance_node(self, history: History) -> bool:
        card0, card1, _ = history
        return card0 is None or card1 is None

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        card0, card1, _ = history
        if card0 is None:
            return [(str(r), 1 / 3) for r in range(3)]
        remaining = [r for r in range(3) if r != card0]
        return [(str(r), 1 / 2) for r in remaining]

    def next_history(self, history: History, action: Action) -> History:
        card0, card1, actions = history
        if card0 is None:
            return (int(action), card1, actions)
        if card1 is None:
            return (card0, int(action), actions)
        return (card0, card1, actions + action)

    def is_terminal(self, history: History) -> bool:
        card0, card1, actions = history
        if card0 is None or card1 is None:
            return False
        return actions in _TERMINAL_ACTIONS

    def current_player(self, history: History) -> int:
        _, _, actions = history
        return len(actions) % 2

    def legal_actions(self, history: History) -> list[Action]:
        return ["p", "b"]

    def returns(self, history: History) -> list[float]:
        card0, card1, actions = history
        higher_is_0 = card0 > card1

        if actions == "pp" or actions in ("bb", "pbb"):
            # Showdown — either no bet was ever made (pp, pot = 2 antes,
            # +/-1) or a bet was made and called (bb / pbb, pot = 2 antes +
            # 2 bets, +/-2).
            stake = 1.0 if actions == "pp" else 2.0
            return [stake, -stake] if higher_is_0 else [-stake, stake]

        if actions == "bp":
            # Player 0 bet, player 1 folded — player 0 wins player 1's ante.
            return [1.0, -1.0]

        if actions == "pbp":
            # Player 0 checked, player 1 bet, player 0 folded.
            return [-1.0, 1.0]

        raise ValueError(f"not a terminal history: {history!r}")

    def information_set_key(self, history: History, player: int) -> str:
        card0, card1, actions = history
        own_card = card0 if player == 0 else card1
        return f"{RANKS[own_card]}:{actions}"
