"""Exhaustive cross-check of the Rust-native `PostflopSubgame` rule port
(Stage 8R-3, `native/src/history.rs` + `native/src/rules.rs`) against the
LIVE Python implementation in `cfr_solver.games.postflop_subgame`.

Unlike `test_postflop_subgame_optimization_regression.py` (which compares a
frozen pre-optimization reference against the current cached code), this
file's ground truth is Python's *current* code -- this is a "new Rust port
vs. existing trusted implementation" comparison. Reuses the exact same
`_reachable_token_strings` exhaustive-enumeration helper that regression
file already established, so coverage of the small reachable-state space is
genuinely exhaustive, not a random sample.
"""

from __future__ import annotations

import pytest

from cfr_solver import _native
from cfr_solver.games import postflop_subgame as pfs
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card

from tests.test_postflop_subgame_optimization_regression import _reachable_token_strings


def _flop_board() -> list[int]:
    return [parse_card(c) for c in ("7h", "2d", "3s")]


def _boards(game: PostflopSubgame) -> list[tuple[int, ...]]:
    turn = game.flop_board + (parse_card("4c"),)
    river = turn + (parse_card("9d"),)
    return [game.flop_board, turn, river]


# -- 0. sanity-check the enumeration itself ----------------------------------


def test_reachable_token_strings_are_genuinely_nontrivial() -> None:
    all_strings: set[str] = set()
    for max_wagers in (1, 2, 3):
        all_strings |= set(_reachable_token_strings(max_wagers))
    # Not a suspiciously small set -- real coverage of check/bet/call/fold/
    # reraise lines across three different wager caps.
    assert len(all_strings) > 20, sorted(all_strings)


# -- 1. `_round_done` / `_round_folded` --------------------------------------


def test_native_round_done_and_folded_match_python_on_every_reachable_string() -> None:
    candidates: set[str] = set()
    for max_wagers in (1, 2, 3):
        candidates |= set(_reachable_token_strings(max_wagers))
    assert len(candidates) > 20
    for tokens in candidates:
        assert _native._debug_round_done(tokens) == pfs._round_done(tokens), tokens
        assert _native._debug_round_folded(tokens) == pfs._round_folded(tokens), tokens


# -- 2. `_legal_for_tokens` ---------------------------------------------------


def test_native_legal_for_tokens_matches_python_on_every_reachable_string() -> None:
    checked = 0
    for max_wagers in (1, 2, 3):
        for tokens in _reachable_token_strings(max_wagers):
            if pfs._round_done(tokens):
                continue
            got = _native._debug_legal_for_tokens(tokens, max_wagers)
            expected = list(pfs._legal_for_tokens(tokens, max_wagers))
            assert got == expected, (tokens, max_wagers)
            checked += 1
    assert checked > 10


def test_native_legal_for_tokens_raises_on_completed_rounds_in_lockstep() -> None:
    for max_wagers in (1, 2, 3):
        for tokens in _reachable_token_strings(max_wagers):
            if not pfs._round_done(tokens):
                continue
            try:
                expected = list(pfs._legal_for_tokens(tokens, max_wagers))
                python_raised = False
            except ValueError:
                python_raised = True
                expected = None
            try:
                got = _native._debug_legal_for_tokens(tokens, max_wagers)
                native_raised = False
            except ValueError:
                native_raised = True
                got = None
            assert python_raised == native_raised, tokens
            if not python_raised:
                assert got == expected, tokens


# -- 3. `_simulate_round` -----------------------------------------------------


def test_native_simulate_round_matches_python_exactly() -> None:
    checked = 0
    for max_wagers in (1, 2, 3):
        for bet_size in (2.5, 5.0, 7.5, 1.0):
            for tokens in _reachable_token_strings(max_wagers):
                got_contrib, got_folder = _native._debug_simulate_round(tokens, bet_size)
                expected_contrib, expected_folder = pfs._simulate_round(tokens, bet_size)
                # Exact float equality: a simple accumulation loop in both
                # languages, no reassociation risk.
                assert got_contrib == expected_contrib, (tokens, bet_size)
                assert got_folder == expected_folder, (tokens, bet_size)
                checked += 1
    assert checked > 100


# -- 4. `_active_round_for` ---------------------------------------------------


def test_native_active_round_for_matches_python() -> None:
    bet_sizes = (2.5, 5.0, 7.5)
    boards = [
        tuple(_flop_board()),
        tuple(_flop_board()) + (parse_card("4c"),),
        tuple(_flop_board()) + (parse_card("4c"), parse_card("9d")),
    ]
    checked = 0
    for max_wagers in (1, 2):
        reachable = _reachable_token_strings(max_wagers)
        for board in boards:
            for flop_a in reachable:
                for turn_a in reachable if len(board) >= 4 else [""]:
                    for river_a in reachable if len(board) == 5 else [""]:
                        got = _native._debug_active_round_for(
                            list(board), flop_a, turn_a, river_a, bet_sizes
                        )
                        expected = pfs._active_round_for(board, flop_a, turn_a, river_a, bet_sizes)
                        assert got == expected, (board, flop_a, turn_a, river_a)
                        checked += 1
    assert checked > 100


# -- 5. `information_set_key` -------------------------------------------------


def test_native_information_set_key_matches_python() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    board5 = game.flop_board + (parse_card("4c"), parse_card("9d"))
    checked = 0
    for hero_combo in game.hero_combos:
        for villain_combo in game.villain_combos:
            if set(hero_combo) & set(villain_combo):
                continue
            for board in (game.flop_board, board5):
                for flop_a, turn_a, river_a in [("", "", ""), ("xb", "", ""), ("xx", "xbc", "")]:
                    history = (hero_combo, villain_combo, board, flop_a, turn_a, river_a)
                    for player in (0, 1):
                        expected = game.information_set_key(history, player)
                        got = _native._debug_information_set_key(
                            hero_combo, villain_combo, list(board), flop_a, turn_a, river_a, player
                        )
                        assert got == expected, history
                        checked += 1
    assert checked > 20


# -- 6. `chance_outcomes` (all three cases, exact order) ----------------------


def test_native_chance_outcomes_hero_deal_matches_python_order() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    history = (None, None, game.flop_board, "", "", "")
    expected = game.chance_outcomes(history)
    got = _native._debug_chance_outcomes(
        game.hero_combos, game.villain_combos, None, None, list(game.flop_board)
    )
    assert got == expected
    assert len(expected) == len(game.hero_combos)


def test_native_chance_outcomes_villain_deal_filters_blockers_in_order() -> None:
    # AKs vs AKo genuinely overlaps hero's dealt combo on some cards, so this
    # exercises the blocker-filter branch (not just the trivial "no overlap"
    # case AA-vs-KK gives above).
    game = PostflopSubgame(_flop_board(), hero_range_notation="AKs", villain_range_notation="AKo")
    hero_combo = game.hero_combos[0]
    history = (hero_combo, None, game.flop_board, "", "", "")
    expected = game.chance_outcomes(history)
    got = _native._debug_chance_outcomes(
        game.hero_combos, game.villain_combos, hero_combo, None, list(game.flop_board)
    )
    assert got == expected
    # sanity: the blocker filter actually removed some combos here
    assert len(expected) < len(game.villain_combos)


def test_native_chance_outcomes_turn_and_river_deal_match_python_order() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    hero_combo = game.hero_combos[0]
    villain_combo = next(c for c in game.villain_combos if not set(c) & set(hero_combo))

    # Turn deal (board still length 3).
    history = (hero_combo, villain_combo, game.flop_board, "xx", "", "")
    expected = game.chance_outcomes(history)
    got = _native._debug_chance_outcomes(
        game.hero_combos, game.villain_combos, hero_combo, villain_combo, list(game.flop_board)
    )
    assert got == expected
    assert len(expected) == 52 - 3 - 2 - 2

    # River deal (board length 4).
    board4 = game.flop_board + (parse_card("4c"),)
    history = (hero_combo, villain_combo, board4, "xx", "xx", "")
    expected = game.chance_outcomes(history)
    got = _native._debug_chance_outcomes(
        game.hero_combos, game.villain_combos, hero_combo, villain_combo, list(board4)
    )
    assert got == expected
    assert len(expected) == 52 - 4 - 2 - 2


def test_native_chance_outcomes_raises_when_every_villain_combo_clashes() -> None:
    # Flop blocks 2 of the 4 aces, leaving exactly one AA combo for both
    # hero's and villain's "AA" range -- so once hero is dealt it, the only
    # possible villain combo is the identical pair of cards, which always
    # clashes.
    board = [parse_card(c) for c in ("As", "Ah", "2c")]
    game = PostflopSubgame(board, hero_range_notation="AA", villain_range_notation="AA")
    assert len(game.hero_combos) == 1 and len(game.villain_combos) == 1
    hero_combo = game.hero_combos[0]
    history = (hero_combo, None, tuple(board), "", "", "")
    with pytest.raises(RuntimeError):
        game.chance_outcomes(history)
    with pytest.raises(RuntimeError):
        _native._debug_chance_outcomes(game.hero_combos, game.villain_combos, hero_combo, None, board)


# -- 7. `is_terminal` / `current_player` -------------------------------------


def test_native_is_terminal_and_current_player_match_python() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    hero_combo = game.hero_combos[0]
    villain_combo = next(c for c in game.villain_combos if not set(c) & set(hero_combo))
    boards = _boards(game)
    terminal_checked = 0
    player_checked = 0
    for max_wagers in (1, 2):
        reachable = _reachable_token_strings(max_wagers)
        for board in boards:
            for flop_a in reachable:
                for turn_a in reachable if len(board) >= 4 else [""]:
                    for river_a in reachable if len(board) == 5 else [""]:
                        history = (hero_combo, villain_combo, board, flop_a, turn_a, river_a)
                        expected_terminal = game.is_terminal(history)
                        got_terminal = _native._debug_is_terminal(
                            hero_combo, villain_combo, list(board), flop_a, turn_a, river_a
                        )
                        assert got_terminal == expected_terminal, history
                        terminal_checked += 1
                        if not expected_terminal and not game.is_chance_node(history):
                            expected_player = game.current_player(history)
                            got_player = _native._debug_current_player(
                                list(board), flop_a, turn_a, river_a, game.bet_sizes
                            )
                            assert got_player == expected_player, history
                            player_checked += 1
    assert terminal_checked > 100
    assert player_checked > 20


# -- 8. `returns` (folded line and full showdown) ----------------------------


def test_native_returns_matches_python_on_a_folded_line() -> None:
    game = PostflopSubgame(
        _flop_board(),
        hero_range_notation="AA",
        villain_range_notation="KK",
        preflop_contrib=(2.5, 2.5),
        bet_sizes=(2.5, 5.0, 7.5),
    )
    hero_combo = game.hero_combos[0]
    villain_combo = next(c for c in game.villain_combos if not set(c) & set(hero_combo))
    flop_board, turn_board, river_board = _boards(game)

    # Fold on the flop, fold on the turn (after a checked-through flop), and
    # fold on the river (after two checked-through streets) -- one case per
    # street's fold-short-circuit branch in `returns`.
    cases = [
        (flop_board, "bf", "", ""),
        (turn_board, "xx", "bf", ""),
        (river_board, "xx", "xx", "bf"),
    ]
    for board, flop_a, turn_a, river_a in cases:
        history = (hero_combo, villain_combo, board, flop_a, turn_a, river_a)
        expected = game.returns(history)
        got = _native._debug_returns(
            hero_combo, villain_combo, list(board), flop_a, turn_a, river_a,
            game.preflop_contrib, game.bet_sizes,
        )
        assert list(got) == expected, history
        assert sum(expected) == pytest.approx(0.0)


def test_native_returns_matches_python_on_a_full_showdown() -> None:
    game = PostflopSubgame(
        _flop_board(),
        hero_range_notation="AA",
        villain_range_notation="KK",
        preflop_contrib=(2.5, 2.5),
        bet_sizes=(2.5, 5.0, 7.5),
    )
    hero_combo = game.hero_combos[0]
    villain_combo = next(c for c in game.villain_combos if not set(c) & set(hero_combo))
    board5 = _boards(game)[2]
    history = (hero_combo, villain_combo, board5, "xx", "xx", "xx")
    expected = game.returns(history)
    got = _native._debug_returns(
        hero_combo, villain_combo, list(board5), "xx", "xx", "xx",
        game.preflop_contrib, game.bet_sizes,
    )
    assert list(got) == expected
    # sanity: AA beats KK on this un-paired board, hero should win the pot
    assert expected[0] > 0 > expected[1]
