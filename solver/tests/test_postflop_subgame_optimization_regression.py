"""Exact-equivalence regression tests for the exploitability-profiling-driven
optimization of `PostflopSubgame` (`BENCHMARKS.md`, the section documenting
the `cProfile` breakdown of `exploitability()` on the AA-vs-KK spot: `walk`
call overhead, `_simulate_round` re-simulating bet tokens from scratch,
`information_set_key`'s `str.join`, and the small per-history dispatch
functions `_active_round`/`legal_actions`/`current_player`/`is_terminal`).

The fix in every case is `functools.lru_cache` on a small, pure, hashable-
input helper (never a change to *what* is computed, only how many times the
same computation is redone) — so this file follows the same methodology as
`tests/test_poker_cards.py`'s fast-hand-evaluator check: a frozen "naive"
reference implementation (copied verbatim from the pre-optimization code,
kept here ONLY to prove the cached version never changed a result) is
compared, exhaustively over every input the real game can actually produce,
against the live (cached) implementation.

This file intentionally does NOT re-derive its own opinion of what the
correct behavior is — it only proves "cached version == pre-optimization
version", which is the actual claim being made.
"""

from __future__ import annotations

import json
from pathlib import Path

from cfr_solver.cfr import CFRSolver
from cfr_solver.games import postflop_subgame as pfs
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card

FIXTURE_DIR = Path(__file__).parent / "fixtures"
# Kept in sync with the iteration count used when the two fixture JSON files
# below were generated against the pre-optimization code (see the
# `capture_small_fixtures.py`-style one-off script referenced in
# BENCHMARKS.md — the fixtures themselves are the durable artifact, not the
# generator script).
FIXTURE_ITERATIONS = 300


def _flop_board() -> list[int]:
    return [parse_card(c) for c in ("7h", "2d", "3s")]


# -- frozen naive references (pre-optimization code, copied verbatim) ------


def _round_done_naive(tokens: str) -> bool:
    return tokens == "xx" or (bool(tokens) and tokens[-1] in ("c", "f"))


def _round_folded_naive(tokens: str) -> bool:
    return bool(tokens) and tokens[-1] == "f"


def _legal_for_tokens_naive(tokens: str, max_wagers: int) -> list[str]:
    if tokens == "" or tokens[-1] == "x":
        return ["x", "b"]
    if tokens[-1] == "b":
        if tokens.count("b") < max_wagers:
            return ["f", "c", "b"]
        return ["f", "c"]
    raise ValueError(f"legal_actions called on a completed round: {tokens!r}")


def _simulate_round_naive(tokens: str, bet_size: float) -> tuple[list[float], int | None]:
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


def _active_round_naive(board, flop_a, turn_a, river_a, bet_sizes):
    if len(board) == 3:
        return (flop_a, bet_sizes[0], 0) if not _round_done_naive(flop_a) else None
    if len(board) == 4:
        return (turn_a, bet_sizes[1], 1) if not _round_done_naive(turn_a) else None
    return (river_a, bet_sizes[2], 2) if not _round_done_naive(river_a) else None


def _card_digits_naive(cards) -> str:
    return "".join(f"{c:02d}" for c in cards)


def _information_set_key_naive(history, player) -> str:
    hero_combo, villain_combo, board, flop_a, turn_a, river_a = history
    own_combo = hero_combo if player == 0 else villain_combo
    combo_digits = "".join(f"{c:02d}" for c in own_combo)
    board_digits = "".join(f"{c:02d}" for c in board)
    return f"{combo_digits}{board_digits}|{flop_a}|{turn_a}|{river_a}"


# -- exhaustive input generation --------------------------------------------
#
# Every token string the real game can actually reach, for a given
# max_wagers_per_round: start at "" and repeatedly apply
# `_legal_for_tokens_naive` (the ground truth for what actions are legal),
# stopping a branch once `_round_done_naive` says the round is over. This
# mirrors exactly how `next_history` grows these strings during real play,
# so it can't accidentally test strings the game itself never produces.


def _reachable_token_strings(max_wagers: int) -> list[str]:
    reachable = [""]
    frontier = [""]
    while frontier:
        next_frontier = []
        for tokens in frontier:
            if _round_done_naive(tokens):
                continue
            for action in _legal_for_tokens_naive(tokens, max_wagers):
                child = tokens + action
                reachable.append(child)
                next_frontier.append(child)
        frontier = next_frontier
    return reachable


def test_reachable_token_strings_are_nonempty_and_include_every_ending() -> None:
    # Sanity-check the generator itself before trusting it below.
    strings = _reachable_token_strings(max_wagers=1)
    assert "" in strings
    assert "xx" in strings  # check-check
    assert "xbc" in strings  # check-bet-call
    assert "xbf" in strings  # check-bet-fold
    assert "bc" in strings  # bet-call
    assert "bf" in strings  # bet-fold


# -- 1. `_round_done` / `_round_folded` -------------------------------------


def test_round_done_matches_naive_reference_on_every_reachable_and_partial_string() -> None:
    # Reachable strings for a couple of max_wagers settings, plus every
    # single-street-alphabet string up to length 5 (a superset that also
    # covers non-reachable but still well-defined inputs).
    alphabet = "xbcf"
    all_short_strings = {""}
    frontier = {""}
    for _ in range(5):
        frontier = {s + ch for s in frontier for ch in alphabet}
        all_short_strings |= frontier

    candidates = set(all_short_strings)
    for max_wagers in (1, 2, 3):
        candidates |= set(_reachable_token_strings(max_wagers))

    assert len(candidates) > 100  # sanity: this is actually exhaustive-ish
    for tokens in candidates:
        assert pfs._round_done(tokens) == _round_done_naive(tokens), tokens
        assert pfs._round_folded(tokens) == _round_folded_naive(tokens), tokens


# -- 2. `_legal_for_tokens` --------------------------------------------------


def test_legal_for_tokens_matches_naive_reference_on_every_reachable_string() -> None:
    for max_wagers in (1, 2, 3):
        for tokens in _reachable_token_strings(max_wagers):
            if _round_done_naive(tokens):
                continue  # both raise ValueError here; nothing to compare
            got = list(pfs._legal_for_tokens(tokens, max_wagers))
            expected = _legal_for_tokens_naive(tokens, max_wagers)
            assert got == expected, (tokens, max_wagers)


def test_legal_for_tokens_raise_or_return_identically_on_completed_rounds() -> None:
    """`_legal_for_tokens` is only ever called by `legal_actions` on a round
    the caller already knows is still active (guarded by `_active_round`
    returning non-None), so its documented "raises on a completed round"
    contract is never actually exercised by real play — and indeed doesn't
    hold uniformly even in the pre-optimization code (e.g. tokens="xx" ends
    in "x", so it hits the `return ["x", "b"]` branch without raising, even
    though `_round_done("xx")` is True). This test doesn't assert what the
    "correct" behavior should be — only that caching changed nothing: for
    every reachable completed-round string, the live (cached) function
    either raises or returns, in lockstep with the naive reference."""
    for max_wagers in (1, 2):
        for tokens in _reachable_token_strings(max_wagers):
            if not _round_done_naive(tokens):
                continue
            try:
                expected = _legal_for_tokens_naive(tokens, max_wagers)
                naive_raised = False
            except ValueError:
                naive_raised = True
            try:
                got = list(pfs._legal_for_tokens(tokens, max_wagers))
                cached_raised = False
            except ValueError:
                cached_raised = True
            assert naive_raised == cached_raised, tokens
            if not naive_raised:
                assert got == expected, tokens


# -- 3. `_simulate_round` ----------------------------------------------------


def test_simulate_round_matches_naive_reference_on_every_reachable_string() -> None:
    for max_wagers in (1, 2, 3):
        for bet_size in (2.5, 5.0, 7.5, 1.0):
            for tokens in _reachable_token_strings(max_wagers):
                got_contrib, got_folder = pfs._simulate_round(tokens, bet_size)
                expected_contrib, expected_folder = _simulate_round_naive(tokens, bet_size)
                assert list(got_contrib) == expected_contrib, (tokens, bet_size)
                assert got_folder == expected_folder, (tokens, bet_size)


# -- 4. `_active_round` / `_active_round_for` --------------------------------


def test_active_round_matches_naive_reference() -> None:
    bet_sizes = (2.5, 5.0, 7.5)
    boards = [
        tuple(_flop_board()),
        tuple(_flop_board()) + (parse_card("4c"),),
        tuple(_flop_board()) + (parse_card("4c"), parse_card("9d")),
    ]
    for max_wagers in (1, 2):
        reachable = _reachable_token_strings(max_wagers)
        for board in boards:
            for flop_a in reachable:
                for turn_a in reachable if len(board) >= 4 else [""]:
                    for river_a in reachable if len(board) == 5 else [""]:
                        got = pfs._active_round_for(board, flop_a, turn_a, river_a, bet_sizes)
                        expected = _active_round_naive(board, flop_a, turn_a, river_a, bet_sizes)
                        assert got == expected, (board, flop_a, turn_a, river_a)


# -- 5. `information_set_key` / `_card_digits` -------------------------------


def test_information_set_key_matches_naive_reference() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="AA", villain_range_notation="KK")
    board5 = game.flop_board + (parse_card("4c"), parse_card("9d"))
    for hero_combo in game.hero_combos:
        for villain_combo in game.villain_combos:
            if set(hero_combo) & set(villain_combo):
                continue
            for board in (game.flop_board, board5):
                for flop_a, turn_a, river_a in [("", "", ""), ("xb", "", ""), ("xx", "xbc", "")]:
                    history = (hero_combo, villain_combo, board, flop_a, turn_a, river_a)
                    for player in (0, 1):
                        got = game.information_set_key(history, player)
                        expected = _information_set_key_naive(history, player)
                        assert got == expected, history


def test_card_digits_matches_naive_reference() -> None:
    game = PostflopSubgame(_flop_board(), hero_range_notation="22+", villain_range_notation="22+")
    for combo in game.hero_combos + game.villain_combos:
        assert pfs._card_digits(combo) == _card_digits_naive(combo)
    assert pfs._card_digits(game.flop_board) == _card_digits_naive(game.flop_board)


# -- 6. Full end-to-end bit-exact regression against a frozen fixture -------
#
# The helper-level tests above prove each optimized piece matches its
# pre-optimization twin in isolation. This test additionally proves the
# *assembled* game (real chance dealing, real CFR training, the actual
# `information_set_key` used as the trainer's storage key) produces a
# bit-for-bit identical `average_strategy()` before and after — the fixture
# was captured by running this exact training call against the
# pre-optimization code (see git history of this file / BENCHMARKS.md for
# how it was captured; same pattern as
# `tests/test_node_storage_regression.py`).
#
# Iteration counts are deliberately small (fast in CI) — unlike exact
# `exploitability()`, whose cost is dominated by the fixed-size real-deck
# turn/river enumeration and stays large regardless of iteration count
# (`BENCHMARKS.md`), `train_external_sampling`'s cost scales with iterations,
# so a small count still exercises every optimized code path (chance
# dealing, betting, showdown, `information_set_key`) while staying fast.


def _load_fixture(name: str) -> dict:
    return json.loads((FIXTURE_DIR / name).read_text())


def test_aa_vs_kk_sampled_training_matches_pre_optimization_fixture_exactly() -> None:
    game = PostflopSubgame(
        _flop_board(),
        hero_range_notation="AA",
        villain_range_notation="KK",
        bet_sizes=(2.5, 5.0, 7.5),
        max_wagers_per_round=1,
    )
    solver = CFRSolver(game, variant="cfr_plus", random_seed=7)
    solver.train_external_sampling(FIXTURE_ITERATIONS)
    assert solver.average_strategy() == _load_fixture("postflop_optimization_aa_vs_kk_small.json")


def test_aa_vs_kk_reraise_sampled_training_matches_pre_optimization_fixture_exactly() -> None:
    """Same spot but max_wagers_per_round=2, so the re-raise ('b' after 'b')
    branch of `_legal_for_tokens`/`_simulate_round` — never reached by the
    max_wagers=1 exported spots — is exercised too."""
    game = PostflopSubgame(
        _flop_board(),
        hero_range_notation="AA",
        villain_range_notation="KK",
        bet_sizes=(2.5, 5.0, 7.5),
        max_wagers_per_round=2,
    )
    solver = CFRSolver(game, variant="cfr_plus", random_seed=11)
    solver.train_external_sampling(FIXTURE_ITERATIONS)
    assert solver.average_strategy() == _load_fixture(
        "postflop_optimization_aa_vs_kk_reraise.json"
    )
