"""Correctness tests for `PostflopSubgame`'s `hand_strength_bucket` option
(`cfr_solver/games/postflop_subgame.py`, `_hand_strength_bucket`).

Unlike `suit_isomorphism`, this IS a real approximation: different combos
that make the same category with the same top kicker collapse onto one CFR
node. These tests check the bucketing itself is computed correctly (matches
`evaluate_best_hand`) and is deterministic/consistent, not that it preserves
every distinction (it deliberately does not).
"""

from __future__ import annotations

from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import evaluate_best_hand, parse_card


def test_default_is_unchanged_raw_card_keys() -> None:
    game = PostflopSubgame(
        [parse_card("2h"), parse_card("7d"), parse_card("Qs")],
        hero_range_notation="AA",
        villain_range_notation="KK",
    )
    assert game.hand_strength_bucket is False
    combo = game.hero_combos[0]
    history = (combo, game.villain_combos[0], game.flop_board, "", "", "")
    key = game.information_set_key(history, player=0)
    combo_digits = "".join(f"{c:02d}" for c in combo)
    assert key.startswith(combo_digits)


def test_bucket_matches_evaluate_best_hand() -> None:
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", hand_strength_bucket=True
    )
    combo = (parse_card("Qh"), parse_card("Qc"))  # trips queens
    villain = game.villain_combos[0]
    key = game.information_set_key((combo, villain, board, "", "", ""), player=0)
    category, *kickers = evaluate_best_hand(list(combo) + list(board))
    expected_kicker = kickers[0] if kickers else -1
    assert key.startswith(f"b{category}{expected_kicker + 1:02d}")


def test_same_category_and_kicker_merge_different_hands() -> None:
    """Two genuinely different hole-card combos that happen to make the same
    category + top kicker against this board must collapse to the same
    key — this is the whole point (and the approximation's cost)."""
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", hand_strength_bucket=True
    )
    villain = game.villain_combos[0]
    seen: dict[str, list] = {}
    merged = False
    for combo in game.hero_combos:
        if set(combo) & set(villain):
            continue
        key = game.information_set_key((combo, villain, board, "", "", ""), player=0)
        seen.setdefault(key, []).append(combo)
        if len(seen[key]) > 1:
            merged = True
    assert merged, "expected at least one (category, top-kicker) collision on a real range"


def test_reduces_distinct_key_count() -> None:
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    raw_game = PostflopSubgame(list(board), hero_range_notation="22+", villain_range_notation="22+")
    bucket_game = PostflopSubgame(
        list(board), hero_range_notation="22+", villain_range_notation="22+", hand_strength_bucket=True
    )
    villain = raw_game.villain_combos[0]
    raw_keys = set()
    bucket_keys = set()
    for combo in raw_game.hero_combos:
        if set(combo) & set(villain):
            continue
        raw_keys.add(raw_game.information_set_key((combo, villain, board, "", "", ""), player=0))
        bucket_keys.add(
            bucket_game.information_set_key((combo, villain, board, "", "", ""), player=0)
        )
    assert len(bucket_keys) < len(raw_keys)


def test_combinable_with_suit_isomorphism() -> None:
    """Both options together must not error and must still only vary the
    board's suit labels, not the hand-strength bucket component."""
    board = (parse_card("2h"), parse_card("7d"), parse_card("Qs"))
    game = PostflopSubgame(
        list(board),
        hero_range_notation="22+",
        villain_range_notation="22+",
        suit_isomorphism=True,
        hand_strength_bucket=True,
    )
    combo = (parse_card("Qh"), parse_card("Qc"))
    villain = game.villain_combos[0]
    key = game.information_set_key((combo, villain, board, "", "", ""), player=0)
    category, *kickers = evaluate_best_hand(list(combo) + list(board))
    expected_kicker = kickers[0] if kickers else -1
    assert key.startswith(f"b{category}{expected_kicker + 1:02d}")
