"""Exhaustive cross-check of the Rust-native hand evaluator (Stage 8R-2)
against the trusted Python reference implementation in `cfr_solver.poker.cards`.

Reuses the exact generation/comparison methodology `test_poker_cards.py`
already established for cross-checking the Python fast evaluator against a
naive reference: same exhaustive hand-shape enumeration, same
order-preservation assertion (`_assert_same_total_order`) rather than
exact-value equality, since the Rust port packs hand ranks into a `u32`
instead of Python's tuple -- only relative order needs to match, never the
concrete encoding (see `cfr_solver/poker/cards.py`'s module docstring and
`native/src/cards.rs`'s).
"""

from __future__ import annotations

import random
from collections import Counter
from itertools import combinations, combinations_with_replacement

from cfr_solver import _native
from cfr_solver.poker.cards import evaluate_5card, evaluate_best_hand

from tests.test_poker_cards import (
    _assert_same_total_order,
    _cards_for_ranks,
    _hand,
)


def test_native_evaluate_5card_matches_python_exhaustively() -> None:
    """Exhaustive over every distinguishable 5-card hand shape: all
    5-distinct-rank combinations (C(13,5) = 1287) crossed with flush/no-flush,
    plus every rank multiset containing a repeat (the other entries of
    `combinations_with_replacement(range(13), 5)`, for which a flush is
    impossible). Identical coverage to
    `test_poker_cards.test_fast_evaluator_matches_naive_reference_exhaustively`
    -- genuinely exhaustive over the full 5-card hand space (2,598,960 hands
    collapse to this many distinguishable rank-shape x flush groups because
    `evaluate_5card`'s result never depends on anything else, e.g. exactly
    which suit a flush is in)."""
    cases: list[list[int]] = []
    for ranks in combinations(range(13), 5):
        cases.append(_cards_for_ranks(ranks, all_same_suit=True))
        cases.append(_cards_for_ranks(ranks, all_same_suit=False))
    for ranks in combinations_with_replacement(range(13), 5):
        if len(set(ranks)) == 5:
            continue  # already covered above
        if Counter(ranks).most_common(1)[0][1] == 5:
            continue  # 5-of-a-kind can't occur in a real 4-suit deck
        cases.append(_cards_for_ranks(ranks, all_same_suit=False))

    python_values = [evaluate_5card(c) for c in cases]
    native_values = [_native.evaluate_5card_native(c) for c in cases]
    _assert_same_total_order(python_values, native_values)


def test_native_evaluate_best_hand_matches_python_on_random_sample() -> None:
    """`evaluate_best_hand` (6-7 cards) just reduces to `evaluate_5card` via
    combinations of 5, already exhaustively verified above -- a large random
    sample here is enough to catch any wiring mistake in that reduction
    itself, mirroring
    `test_poker_cards.test_fast_evaluate_best_hand_matches_naive_reference_on_random_sample`.
    """
    rng = random.Random(0)
    deck = list(range(52))
    hands = [rng.sample(deck, 7) for _ in range(20_000)]
    python_values = [evaluate_best_hand(h) for h in hands]
    native_values = [_native.evaluate_best_hand_native(h) for h in hands]
    _assert_same_total_order(python_values, native_values)


def test_native_wheel_straight_ranks_as_five_high() -> None:
    wheel = _native.evaluate_5card_native(_hand("5h 4s 3d 2c Ah"))
    six_high = _native.evaluate_5card_native(_hand("6h 5s 4d 3c 2h"))
    assert wheel < six_high, "A-2-3-4-5 must rank as a 5-high straight, not an ace-high hand"


def test_native_wheel_straight_flush_beats_quads() -> None:
    wheel_flush = _native.evaluate_5card_native(_hand("5h 4h 3h 2h Ah"))
    quads = _native.evaluate_5card_native(_hand("Kh Ks Kd Kc 2h"))
    assert wheel_flush > quads
