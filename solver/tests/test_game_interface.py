"""Generic conformance checks that apply to any `Game` implementation.

`assert_game_is_well_formed` is reused unmodified by every game's own test
file (Kuhn, Leduc, 3-player Kuhn, and eventually a real postflop subgame in
a later phase) — it never hardcodes anything game-specific.
"""

from __future__ import annotations

import math

from cfr_solver.games.game import Game


def assert_game_is_well_formed(game: Game, *, max_histories: int = 200_000) -> None:
    """Walk the full game tree and check the `Game` contract holds everywhere.

    Raises AssertionError on the first violation found. `max_histories` is a
    safety valve against accidentally walking an unbounded tree (a real bug
    would otherwise hang the test suite instead of failing fast).
    """
    visited = 0

    def walk(history) -> None:
        nonlocal visited
        visited += 1
        assert visited <= max_histories, (
            f"walked more than {max_histories} histories — either the game "
            "tree is unexpectedly large, or next_history/is_terminal never "
            "reaches a terminal state"
        )

        if game.is_terminal(history):
            returns = game.returns(history)
            assert len(returns) == game.num_players, (
                f"returns() length {len(returns)} != num_players "
                f"{game.num_players} at terminal history {history!r}"
            )
            assert math.isclose(sum(returns), 0.0, abs_tol=1e-9), (
                f"terminal returns {returns} at {history!r} do not sum to "
                "zero (game must be zero-sum)"
            )
            return

        if game.is_chance_node(history):
            outcomes = game.chance_outcomes(history)
            assert outcomes, f"chance node {history!r} has no outcomes"
            total_prob = sum(prob for _, prob in outcomes)
            assert math.isclose(total_prob, 1.0, abs_tol=1e-9), (
                f"chance outcome probabilities at {history!r} sum to "
                f"{total_prob}, not 1"
            )
            for action, prob in outcomes:
                assert prob > 0, f"chance outcome {action!r} has non-positive probability {prob}"
                walk(game.next_history(history, action))
            return

        player = game.current_player(history)
        assert 0 <= player < game.num_players, (
            f"current_player {player} out of range for num_players "
            f"{game.num_players} at {history!r}"
        )

        actions = game.legal_actions(history)
        assert actions, f"non-terminal, non-chance history {history!r} has no legal actions"

        # information_set_key must not raise, and must not depend on
        # information the acting player cannot see — we cannot verify the
        # "cannot see" half generically, but we can at least confirm the key
        # exists and is a string.
        key = game.information_set_key(history, player)
        assert isinstance(key, str) and key, (
            f"information_set_key({history!r}, {player}) must return a "
            "non-empty string"
        )

        for action in actions:
            walk(game.next_history(history, action))

    walk(game.new_initial_history())
    assert visited > 1, "game tree only has a single (terminal) history — nothing to solve"
