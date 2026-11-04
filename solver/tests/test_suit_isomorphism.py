"""Correctness tests for `PostflopSubgame`'s `suit_isomorphism` option
(`cfr_solver/games/postflop_subgame.py`, `_canonical_suit_map`).

The claim under test: relabeling suits to a canonical order merges only
genuinely-identical (suit-permuted) situations, and never two hands that
actually differ. See `_canonical_suit_map`'s docstring for why this
particular relabeling is an exact reduction, not a card-bucketing
approximation.
"""

from __future__ import annotations

from itertools import permutations

from cfr_solver.games.postflop_subgame import PostflopSubgame, _canonical_suit_map
from cfr_solver.poker.cards import parse_card, rank_of, suit_of


def _permute_suit(card: int, perm: tuple[int, int, int, int]) -> int:
    return rank_of(card) * 4 + perm[suit_of(card)]


def test_default_is_unchanged_raw_card_keys() -> None:
    """`suit_isomorphism` defaults to False: existing (frozen-fixture) callers
    must see exactly the old raw-card-digit key, unchanged."""
    game = PostflopSubgame(
        [parse_card("2h"), parse_card("7d"), parse_card("Qs")],
        hero_range_notation="AA",
        villain_range_notation="KK",
    )
    assert game.suit_isomorphism is False
    combo = game.hero_combos[0]
    history = (combo, game.villain_combos[0], game.flop_board, "", "", "")
    key = game.information_set_key(history, player=0)
    combo_digits = "".join(f"{c:02d}" for c in combo)
    board_digits = "".join(f"{c:02d}" for c in game.flop_board)
    assert key == f"{combo_digits}{board_digits}|||"


def test_suit_permuted_deals_produce_identical_key() -> None:
    """Swapping all 4 suits consistently everywhere (board + own hole cards)
    must not change the information-set key when suit_isomorphism=True —
    the whole point of the reduction."""
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    combo = (parse_card("Ah"), parse_card("Kh"))  # suited, same suit as a board card
    game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", suit_isomorphism=True
    )
    base_key = game.information_set_key((combo, game.villain_combos[0], board, "x", "", ""), player=0)

    for perm in permutations(range(4)):
        permuted_board = tuple(_permute_suit(c, perm) for c in board)
        permuted_combo = tuple(_permute_suit(c, perm) for c in combo)
        key = game.information_set_key(
            (permuted_combo, game.villain_combos[0], permuted_board, "x", "", ""), player=0
        )
        assert key == base_key, (perm, key, base_key)


def test_suitedness_is_preserved_not_merged_away() -> None:
    """A suited and an offsuit combo of the same two ranks must still get
    different keys — the reduction must never erase real information."""
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", suit_isomorphism=True
    )
    suited = (parse_card("Ah"), parse_card("Kh"))
    offsuit = (parse_card("Ah"), parse_card("Kc"))
    villain = game.villain_combos[0]
    key_suited = game.information_set_key((suited, villain, board, "", "", ""), player=0)
    key_offsuit = game.information_set_key((offsuit, villain, board, "", "", ""), player=0)
    assert key_suited != key_offsuit


def test_different_ranks_are_never_merged() -> None:
    """Two genuinely different hands (different ranks) must never collide,
    for any suit assignment — the reduction only ever normalizes the
    meaningless suit label, never the ranks."""
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", suit_isomorphism=True
    )
    villain = game.villain_combos[0]
    seen = {}
    for combo in game.hero_combos:
        if set(combo) & set(villain):
            continue
        key = game.information_set_key((combo, villain, board, "", "", ""), player=0)
        rank_pair = tuple(sorted(rank_of(c) for c in combo))
        if key in seen:
            assert seen[key] == rank_pair, (key, seen[key], rank_pair, combo)
        else:
            seen[key] = rank_pair


def test_reduces_distinct_key_count_on_a_real_range() -> None:
    """Sanity check that the reduction actually does something on a board
    where it should: a monotone board uses only 1 of the 4 suits, leaving
    the other 3 fully interchangeable (see `_canonical_suit_map`'s
    docstring) — a 3-rainbow board (one card per suit, 1 suit totally
    unused) has no second free suit to merge the lone unused suit with, so
    it is deliberately NOT used here (that board texture's real reduction
    comes from the turn/river cards dealt during training, not the flop
    alone — out of scope for this single-street unit test)."""
    board = (parse_card("Ah"), parse_card("Th"), parse_card("6h"))
    raw_game = PostflopSubgame(list(board), hero_range_notation="22+", villain_range_notation="22+")
    iso_game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", suit_isomorphism=True
    )
    villain = raw_game.villain_combos[0]
    raw_keys = set()
    iso_keys = set()
    for combo in raw_game.hero_combos:
        if set(combo) & set(villain):
            continue
        raw_keys.add(raw_game.information_set_key((combo, villain, board, "", "", ""), player=0))
        iso_keys.add(iso_game.information_set_key((combo, villain, board, "", "", ""), player=0))
    assert len(iso_keys) < len(raw_keys)


def test_canonical_suit_map_is_a_bijection() -> None:
    for visible in [
        (parse_card("Ah"), parse_card("Kh"), parse_card("2h"), parse_card("7d"), parse_card("Qs")),
        (parse_card("As"), parse_card("Ks"), parse_card("2h"), parse_card("7d"), parse_card("Qs")),
        (parse_card("2c"), parse_card("3c"), parse_card("2h"), parse_card("7d"), parse_card("Qs")),
    ]:
        suit_map = _canonical_suit_map(visible)
        assert sorted(suit_map) == [0, 1, 2, 3]
