"""3-player Kuhn Poker — verification benchmark #3 (N-player self-play).

Extends Kuhn Poker to 3 simultaneously-live players, following the
simplification common in multiplayer-CFR research (e.g. Abou Risk &
Szafron, 2010, "Using Counterfactual Regret Minimization to Create
Competitive Multiplayer Poker Agents"): a 4-card deck (one of each of 4
ranks; 3 are dealt, 1 stays in the deck), single bet size 1, and — to keep
the benchmark small and unambiguous — no re-raising once a bet has been
made (each other player's one response is fold or call).

**This game is NOT solvable for a proven Nash equilibrium the way 2-player
Kuhn Poker is** — with 3 simultaneously-live players, self-play CFR is not
guaranteed to converge to a single, well-defined equilibrium (this is
exactly the mathematical limitation documented in the project plan and
`BENCHMARKS.md`: Nash equilibria are only guaranteed unique for two-player
zero-sum games). What this benchmark verifies instead is that the N-player
generalization of `cfr.py` and `exploitability.py` behaves sensibly on a
known small game: `exploitability_per_player` should trend down as
self-play training continues, even without a single proven target value to
converge to.

Action encoding: "p" = pass/check (only legal before any bet), "b" = bet
(only legal before any bet), "f" = fold, "c" = call (fold/call only legal
once responding to a bet). `History` is `(card0, card1, card2, actions)`
where each card is a rank 0..3 (J/Q/K/A) and `actions` is the flat sequence
of action characters taken so far, in turn order (skipping folded players).
"""

from __future__ import annotations

from typing import NamedTuple

from cfr_solver.games.game import Action, Game, History

RANKS = ("J", "Q", "K", "A")
NUM_PLAYERS = 3
BET_SIZE = 1.0
ANTE = 1.0


class _ReplayState(NamedTuple):
    active: tuple[bool, ...]
    contrib: tuple[float, ...]
    bettor: int | None
    terminal: bool
    next_actor: int | None


def _advance(actor: int, active: tuple[bool, ...]) -> int:
    nxt = (actor + 1) % NUM_PLAYERS
    while not active[nxt]:
        nxt = (nxt + 1) % NUM_PLAYERS
    return nxt


def _replay(actions: str) -> _ReplayState:
    active = [True] * NUM_PLAYERS
    contrib = [0.0] * NUM_PLAYERS
    bettor: int | None = None
    responded: set[int] = set()
    actor = 0

    for ch in actions:
        if ch == "p":
            actor = _advance(actor, tuple(active))
        elif ch == "b":
            bettor = actor
            contrib[actor] = BET_SIZE
            responded = {actor}
            actor = _advance(actor, tuple(active))
        elif ch == "c":
            contrib[actor] = BET_SIZE
            responded.add(actor)
            actor = _advance(actor, tuple(active))
        elif ch == "f":
            active[actor] = False
            responded.add(actor)
            if sum(active) == 1:
                return _ReplayState(tuple(active), tuple(contrib), bettor, True, None)
            actor = _advance(actor, tuple(active))
        else:
            raise ValueError(f"unknown action {ch!r}")

    if bettor is None:
        terminal = len(actions) == NUM_PLAYERS
    else:
        active_players = {i for i in range(NUM_PLAYERS) if active[i]}
        terminal = responded >= active_players

    next_actor = None if terminal else actor
    return _ReplayState(tuple(active), tuple(contrib), bettor, terminal, next_actor)


class ThreePlayerKuhnPoker(Game):
    @property
    def num_players(self) -> int:
        return NUM_PLAYERS

    def new_initial_history(self) -> History:
        return (None, None, None, "")

    def is_chance_node(self, history: History) -> bool:
        card0, card1, card2, _actions = history
        return card0 is None or card1 is None or card2 is None

    def chance_outcomes(self, history: History) -> list[tuple[Action, float]]:
        card0, card1, card2, _actions = history
        dealt = [c for c in (card0, card1, card2) if c is not None]
        remaining = [r for r in range(4) if r not in dealt]
        return [(str(r), 1 / len(remaining)) for r in remaining]

    def next_history(self, history: History, action: Action) -> History:
        card0, card1, card2, actions = history
        if card0 is None:
            return (int(action), card1, card2, actions)
        if card1 is None:
            return (card0, int(action), card2, actions)
        if card2 is None:
            return (card0, card1, int(action), actions)
        return (card0, card1, card2, actions + action)

    def is_terminal(self, history: History) -> bool:
        card0, card1, card2, actions = history
        if card0 is None or card1 is None or card2 is None:
            return False
        return _replay(actions).terminal

    def current_player(self, history: History) -> int:
        _c0, _c1, _c2, actions = history
        state = _replay(actions)
        assert state.next_actor is not None
        return state.next_actor

    def legal_actions(self, history: History) -> list[Action]:
        _c0, _c1, _c2, actions = history
        state = _replay(actions)
        return ["p", "b"] if state.bettor is None else ["f", "c"]

    def returns(self, history: History) -> list[float]:
        card0, card1, card2, actions = history
        cards = (card0, card1, card2)
        state = _replay(actions)
        total = [ANTE + c for c in state.contrib]
        pot = sum(total)

        active_idx = [i for i in range(NUM_PLAYERS) if state.active[i]]
        best_rank = max(cards[i] for i in active_idx)
        winners = [i for i in active_idx if cards[i] == best_rank]

        share = pot / len(winners)
        return [share - total[i] if i in winners else -total[i] for i in range(NUM_PLAYERS)]

    def information_set_key(self, history: History, player: int) -> str:
        card0, card1, card2, actions = history
        own_card = (card0, card1, card2)[player]
        return f"{RANKS[own_card]}:{actions}"
