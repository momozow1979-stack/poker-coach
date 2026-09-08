"""Bit-exact regression gate for `_native.EquityCache`, the compact Rust
replacement for `PostflopSubgame._equity_cache`
(`dict[tuple[Combo, Combo, tuple[int, ...]], float]`).

Measured motivation (see `BENCHMARKS.md`'s "全ハンド対応 Stage S5" entry):
the old dict-keyed-by-nested-tuples design cost ~347 bytes/entry -- worse
than the ~192 B/entry the original `_index: dict[str, int]` cost before
`NodeIndex` replaced it, and Stage S2 measured this cache holds 27-34% as
many entries as information sets, making it a large, previously
unisolated contributor to Stage S4's measured full-hand-range memory
ceiling.

This is a pure storage-layout change -- `_equity()` only ever returns one
of exactly three values (0.0, 0.5, 1.0), decided by comparing two hand
ranks via `evaluate_best_hand`, which is untouched. So (matching this
package's established discipline for storage-only refactors --
`test_node_storage_regression.py`'s own docstring) every check here is
exact equality, never a tolerance.
"""

from __future__ import annotations

import pickle
import random

from cfr_solver import _native
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import evaluate_best_hand, parse_card


def _reference_equity(hero: tuple[int, int], villain: tuple[int, int], board: tuple[int, ...]) -> float:
    """Independent reimplementation of the pre-Stage-S5 `_equity` logic
    (the dict-cache version this test guards against regressing), used as
    the ground truth -- never the thing under test."""
    hero_rank = evaluate_best_hand(list(hero) + list(board))
    villain_rank = evaluate_best_hand(list(villain) + list(board))
    if hero_rank > villain_rank:
        return 1.0
    if hero_rank < villain_rank:
        return 0.0
    return 0.5


def test_matches_reference_equity_over_many_random_showdowns() -> None:
    cache = _native.EquityCache()
    rng = random.Random(7)
    for _ in range(20_000):
        cards = rng.sample(range(52), 9)
        hero = (cards[0], cards[1])
        villain = (cards[2], cards[3])
        board = tuple(cards[4:9])
        expected = _reference_equity(hero, villain, board)
        assert cache.equity(hero, villain, board) == expected


def test_repeated_lookup_of_the_same_key_returns_the_same_cached_value() -> None:
    cache = _native.EquityCache()
    hero, villain, board = (0, 1), (2, 3), (4, 5, 6, 7, 8)
    first = cache.equity(hero, villain, board)
    assert cache.equity(hero, villain, board) == first
    assert len(cache) == 1


def test_distinct_keys_do_not_collide_in_practice() -> None:
    cache = _native.EquityCache()
    rng = random.Random(11)
    seen: dict[tuple, float] = {}
    for _ in range(5_000):
        cards = rng.sample(range(52), 9)
        hero = (cards[0], cards[1])
        villain = (cards[2], cards[3])
        board = tuple(cards[4:9])
        key = (hero, villain, board)
        got = cache.equity(hero, villain, board)
        if key in seen:
            assert got == seen[key]
        else:
            seen[key] = got
    assert len(cache) == len(seen)


def test_pickle_round_trips_cache_contents_exactly() -> None:
    cache = _native.EquityCache()
    rng = random.Random(3)
    entries = []
    for _ in range(500):
        cards = rng.sample(range(52), 9)
        hero = (cards[0], cards[1])
        villain = (cards[2], cards[3])
        board = tuple(cards[4:9])
        entries.append((hero, villain, board, cache.equity(hero, villain, board)))

    restored = pickle.loads(pickle.dumps(cache))
    assert len(restored) == len(cache)
    for hero, villain, board, expected in entries:
        # Looking these up again must hit the restored cache and return the
        # exact same value that was originally computed -- not silently
        # recompute a fresh (possibly still-correct-but-untested) value.
        assert restored.equity(hero, villain, board) == expected


def test_postflop_subgame_is_still_picklable() -> None:
    """`exploitability.py`'s Stage 7 `ProcessPoolExecutor`-based parallel
    path pickles `game` (via `initargs`) to send it to worker processes. A
    plain `dict`-backed `_equity_cache` round-tripped through pickle for
    free; replacing it with a `#[pyclass]` does not do this automatically
    -- this test exists specifically to catch that regression, which was
    real and reproduced directly while building this feature."""
    board = [parse_card(c) for c in ("7h", "2d", "3s")]
    game = PostflopSubgame(board, hero_range_notation="AA", villain_range_notation="KK")

    restored = pickle.loads(pickle.dumps(game))

    assert restored.hero_combos == game.hero_combos
    assert restored.villain_combos == game.villain_combos


def test_board_longer_than_capacity_raises_instead_of_corrupting() -> None:
    cache = _native.EquityCache()
    try:
        cache.equity((0, 1), (2, 3), tuple(range(20)))
    except ValueError:
        return
    raise AssertionError("expected a ValueError for an over-long board")
