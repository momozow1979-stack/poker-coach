"""Abstract extensive-form game interface shared by every game in this package.

Every game (Kuhn Poker, Leduc Hold'em, the 3-player Kuhn Poker variant, and
eventually a real heads-up postflop subgame) implements this same small
contract. `cfr.py` and `exploitability.py` are written entirely against this
interface and never against a specific game, so they can be reused unmodified
as new games are added.

`History` is deliberately left as `Any` — each game defines its own concrete
representation (a tuple of dealt cards + an action string is enough for the
small games in this package).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

History = Any
Action = str


class Game(ABC):
    """A finite, perfect-recall extensive-form game with chance nodes.

    Utilities returned by `returns` must sum to zero across all players at
    every terminal history (the games here are zero-sum, as poker is).
    """

    @property
    @abstractmethod
    def num_players(self) -> int:
        """Number of acting players (chance is not a player)."""

    @abstractmethod
    def new_initial_history(self) -> History:
        """The empty history at the start of the game."""

    @abstractmethod
    def is_terminal(self, history: History) -> bool:
        """Whether no further actions can be taken from this history."""

    @abstractmethod
    def is_chance_node(self, history: History) -> bool:
        """Whether the next event is a chance event (e.g. a card deal)."""

    @abstractmethod
    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        """Possible chance outcomes and their probabilities (must sum to 1).

        Only called when `is_chance_node(history)` is True.
        """

    @abstractmethod
    def current_player(self, history: History) -> int:
        """Index (0..num_players-1) of the player to act.

        Only called when history is neither terminal nor a chance node.
        """

    @abstractmethod
    def legal_actions(self, history: History) -> list[Action]:
        """Actions available to `current_player(history)`."""

    @abstractmethod
    def next_history(self, history: History, action: Action) -> History:
        """The history that results from taking `action` at `history`."""

    @abstractmethod
    def returns(self, history: History) -> list[float]:
        """Per-player utility at a terminal history. Must sum to 0.

        Only called when `is_terminal(history)` is True.
        """

    @abstractmethod
    def information_set_key(self, history: History, player: int) -> str:
        """The string `player` actually observes at `history`.

        Must encode exactly what that player can see: their own private
        card(s) and the public action/board history — never another
        player's hidden information. This is where imperfect information
        is encoded; CFR itself only ever looks at these keys, never at
        `History` directly.
        """
