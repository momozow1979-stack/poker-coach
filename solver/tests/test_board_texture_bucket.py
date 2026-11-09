"""Correctness tests for `PostflopSubgame`'s `board_texture_bucket` option
(`cfr_solver/games/postflop_subgame.py`, `_card_texture_delta` /
`_board_texture_key`).

This IS a real approximation (like `hand_strength_bucket`, unlike
`suit_isomorphism`): it targets the explosion from the ~1,892 possible
(turn, river) card pairs a fixed flop can see during training, by replacing
each dealt card's exact identity with its texture effect on the board
(pairs it? advances a flush?) relative to the board before it.
"""

from __future__ import annotations

from cfr_solver.games.postflop_subgame import PostflopSubgame, _card_texture_delta
from cfr_solver.poker.cards import parse_card


def test_default_is_unchanged_raw_card_keys() -> None:
    board = (parse_card("2h"), parse_card("7d"), parse_card("2c"))
    game = PostflopSubgame(list(board), hero_range_notation="AA", villain_range_notation="KK")
    assert game.board_texture_bucket is False
    combo = game.hero_combos[0]
    board5 = board + (parse_card("9s"), parse_card("4d"))
    history = (combo, game.villain_combos[0], board5, "xx", "xx", "")
    key = game.information_set_key(history, player=0)
    assert "".join(f"{c:02d}" for c in board5) in key
    assert "t" not in key  # no texture markers when the option is off


def test_pairs_board_detected() -> None:
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qc"))
    pairs, flush = _card_texture_delta(parse_card("7s"), board)  # pairs the 7
    assert pairs == 1
    pairs, flush = _card_texture_delta(parse_card("4s"), board)  # no pair
    assert pairs == 0


def test_advances_flush_detected() -> None:
    board = (parse_card("2h"), parse_card("7h"), parse_card("Qc"))  # 2 hearts already
    pairs, flush = _card_texture_delta(parse_card("9h"), board)  # 3rd heart
    assert flush == 1
    pairs, flush = _card_texture_delta(parse_card("9s"), board)  # off-suit
    assert flush == 0


def test_no_flush_signal_with_only_one_suited_card() -> None:
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qc"))  # all different suits
    pairs, flush = _card_texture_delta(parse_card("9h"), board)  # only 2nd heart, not yet 2+
    assert flush == 0


def test_flop_stays_literal_turn_river_become_texture() -> None:
    flop = (parse_card("2h"), parse_card("7d"), parse_card("Qc"))
    game = PostflopSubgame(
        list(flop), hero_range_notation="22+", villain_range_notation="22+", board_texture_bucket=True
    )
    villain = game.villain_combos[0]
    combo = game.hero_combos[0]
    if set(combo) & set(villain):
        combo = game.hero_combos[1]
    board5 = flop + (parse_card("7s"), parse_card("4d"))  # turn pairs the board
    key = game.information_set_key((combo, villain, board5, "xx", "xx", ""), player=0)
    flop_digits = "".join(f"{c:02d}" for c in flop)
    assert flop_digits in key
    assert "t10" in key  # turn: pairs_board=1, advances_flush=0
    assert "t00" in key  # river (4d): no pair, no flush


def test_different_cards_with_same_texture_merge() -> None:
    """Two different turn cards that both 'pair the board, no flush' must
    produce the same key — the intended effect."""
    flop = (parse_card("2h"), parse_card("7d"), parse_card("Qc"))
    game = PostflopSubgame(
        list(flop), hero_range_notation="22+", villain_range_notation="22+", board_texture_bucket=True
    )
    villain = game.villain_combos[0]
    combo = game.hero_combos[0]
    if set(combo) & set(villain):
        combo = game.hero_combos[1]
    key_a = game.information_set_key((combo, villain, flop + (parse_card("2s"),), "x", "", ""), player=0)
    key_b = game.information_set_key((combo, villain, flop + (parse_card("2d"),), "x", "", ""), player=0)
    assert key_a == key_b


def test_reduces_distinct_key_count_over_turn_river_deals() -> None:
    flop = (parse_card("2h"), parse_card("7d"), parse_card("Qc"))
    raw_game = PostflopSubgame(list(flop), hero_range_notation="AA", villain_range_notation="KK")
    bucket_game = PostflopSubgame(
        list(flop), hero_range_notation="AA", villain_range_notation="KK", board_texture_bucket=True
    )
    combo = raw_game.hero_combos[0]
    villain = raw_game.villain_combos[0]
    used = set(flop) | set(combo) | set(villain)
    remaining = [c for c in range(52) if c not in used]
    raw_keys = set()
    bucket_keys = set()
    for turn in remaining[:15]:
        board4 = flop + (turn,)
        raw_keys.add(raw_game.information_set_key((combo, villain, board4, "x", "", ""), player=0))
        bucket_keys.add(
            bucket_game.information_set_key((combo, villain, board4, "x", "", ""), player=0)
        )
    assert len(bucket_keys) < len(raw_keys)
