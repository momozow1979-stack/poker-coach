"""Sanity checks for the 5-card hand evaluator and card parsing."""

from __future__ import annotations

from collections import Counter
from itertools import combinations, combinations_with_replacement

from cfr_solver.poker.cards import (
    card_str,
    evaluate_5card,
    evaluate_best_hand,
    parse_card,
)


def _hand(text: str) -> list[int]:
    return [parse_card(c) for c in text.split()]


def test_parse_and_format_round_trip() -> None:
    for text in ("As", "Kh", "2c", "Td"):
        assert card_str(parse_card(text)) == text


def test_hand_categories_rank_in_the_correct_order() -> None:
    hands = [
        "As Ks Qs Js Ts",  # straight flush (royal)
        "Ah As Ad Ac 2s",  # quads
        "Ah As Ad 2s 2h",  # full house
        "Ah Kh 9h 5h 2h",  # flush
        "9h 8s 7d 6c 5h",  # straight
        "Ah As Ad 5c 2h",  # trips
        "Ah As Kd Kc 2h",  # two pair
        "Ah As Kd Qc 2h",  # one pair
        "Ah Ks Qd Jc 9h",  # high card
    ]
    values = [evaluate_5card(_hand(h)) for h in hands]
    assert values == sorted(values, reverse=True)


def test_wheel_straight_ranks_as_five_high() -> None:
    wheel = evaluate_5card(_hand("5h 4s 3d 2c Ah"))
    six_high = evaluate_5card(_hand("6h 5s 4d 3c 2h"))
    assert wheel < six_high, "A-2-3-4-5 must rank as a 5-high straight, not an ace-high hand"


def test_wheel_straight_flush_beats_quads() -> None:
    wheel_flush = evaluate_5card(_hand("5h 4h 3h 2h Ah"))
    quads = evaluate_5card(_hand("Kh Ks Kd Kc 2h"))
    assert wheel_flush > quads


# -- exhaustive cross-check of the fast (table-based) evaluator ------------
#
# `cards.py` replaced the original `Counter`/`sorted()`-per-call evaluator
# with a perfect-hash lookup scheme for speed (see its module docstring —
# this matters because `exploitability.best_response_value` calls it inside
# a ~44x43 enumeration per combo pair, per `BENCHMARKS.md`). Nothing depends
# on the exact tuple *values* returned, only the relative order, so this
# reference implementation (the pre-optimization code, kept here only to
# prove the fast version didn't change any ordering) is checked against the
# fast one below.


def _evaluate_5card_naive(cards: list[int]) -> tuple[int, ...]:
    from cfr_solver.poker.cards import rank_of, suit_of

    ranks = sorted((rank_of(c) for c in cards), reverse=True)
    suits = [suit_of(c) for c in cards]
    is_flush = len(set(suits)) == 1

    counts = Counter(ranks)
    by_count_then_rank = sorted(counts.items(), key=lambda kv: (-kv[1], -kv[0]))
    count_pattern = tuple(count for _, count in by_count_then_rank)
    ordered_ranks = tuple(rank for rank, _ in by_count_then_rank)

    unique_ranks = sorted(set(ranks), reverse=True)
    is_straight = False
    straight_high = -1
    if len(unique_ranks) == 5:
        if unique_ranks[0] - unique_ranks[4] == 4:
            is_straight = True
            straight_high = unique_ranks[0]
        elif unique_ranks == [12, 3, 2, 1, 0]:
            is_straight = True
            straight_high = 3

    HIGH_CARD, ONE_PAIR, TWO_PAIR, TRIPS, STRAIGHT, FLUSH, FULL_HOUSE, QUADS, STRAIGHT_FLUSH = range(9)
    if is_straight and is_flush:
        return (STRAIGHT_FLUSH, straight_high)
    if count_pattern == (4, 1):
        return (QUADS, *ordered_ranks)
    if count_pattern == (3, 2):
        return (FULL_HOUSE, *ordered_ranks)
    if is_flush:
        return (FLUSH, *ranks)
    if is_straight:
        return (STRAIGHT, straight_high)
    if count_pattern == (3, 1, 1):
        return (TRIPS, *ordered_ranks)
    if count_pattern == (2, 2, 1):
        return (TWO_PAIR, *ordered_ranks)
    if count_pattern == (2, 1, 1, 1):
        return (ONE_PAIR, *ordered_ranks)
    return (HIGH_CARD, *ranks)


def _cards_for_ranks(ranks: tuple[int, ...], *, all_same_suit: bool) -> list[int]:
    """Build 5 concrete card ids for a rank multiset. `evaluate_5card`'s
    result depends only on the rank multiset and whether all 5 suits match
    (never on *which* suit) — see the module docstring's reasoning about why
    a repeated rank can never be a flush — so this is enough to exhaustively
    cover every distinguishable input without enumerating all C(52,5) hands."""
    if all_same_suit:
        return [r * 4 + 0 for r in ranks]
    seen_count: dict[int, int] = {}
    cards = []
    for r in ranks:
        suit = seen_count.get(r, 0)
        seen_count[r] = suit + 1
        cards.append(r * 4 + suit)
    return cards


def _assert_same_total_order(naive_values: list, fast_values: list) -> None:
    """`naive_values[i]`/`fast_values[i]` are two evaluators' outputs for the
    same sequence of hands. They induce the same total order (same `<` and
    same `==` relation over the whole set) iff sorting by one, in the same
    permutation, always yields a non-decreasing sequence in the other — and
    that has to hold in *both* directions (naive-order implies fast is
    non-decreasing, and vice versa), otherwise one evaluator could be finer
    (draw a distinction the other doesn't) without the check noticing.
    """
    n = len(naive_values)
    assert n == len(fast_values)
    by_naive = sorted(range(n), key=lambda i: naive_values[i])
    fast_in_naive_order = [fast_values[i] for i in by_naive]
    assert fast_in_naive_order == sorted(fast_in_naive_order), (
        "sorting by the naive evaluator did not yield a non-decreasing sequence "
        "under the fast evaluator — the two disagree on some pair's relative order"
    )
    by_fast = sorted(range(n), key=lambda i: fast_values[i])
    naive_in_fast_order = [naive_values[i] for i in by_fast]
    assert naive_in_fast_order == sorted(naive_in_fast_order), (
        "sorting by the fast evaluator did not yield a non-decreasing sequence "
        "under the naive evaluator — the two disagree on some pair's relative order"
    )


def test_fast_evaluator_matches_naive_reference_exhaustively() -> None:
    """Exhaustive over every distinguishable 5-card hand shape: all
    5-distinct-rank combinations (C(13,5) = 1287) crossed with flush/no-flush,
    plus every rank multiset containing a repeat (the other ~4900 entries of
    `combinations_with_replacement(range(13), 5)`, for which a flush is
    impossible — see the module docstring). This is exhaustive, not a
    sample: `evaluate_5card`'s value never depends on anything else."""
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

    naive_values = [_evaluate_5card_naive(c) for c in cases]
    fast_values = [evaluate_5card(c) for c in cases]
    _assert_same_total_order(naive_values, fast_values)


def test_fast_evaluate_best_hand_matches_naive_reference_on_random_sample() -> None:
    """`evaluate_best_hand` (6-7 cards) just reduces to `evaluate_5card` via
    `itertools.combinations`, already exhaustively verified above — a large
    random sample here is enough to catch any wiring mistake in that
    reduction itself, without re-deriving the whole evaluator's correctness."""
    import random

    def naive_best(cards: list[int]) -> tuple[int, ...]:
        if len(cards) == 5:
            return _evaluate_5card_naive(cards)
        return max(_evaluate_5card_naive(list(five)) for five in combinations(cards, 5))

    rng = random.Random(0)
    deck = list(range(52))
    hands = [rng.sample(deck, 7) for _ in range(20_000)]
    naive_values = [naive_best(h) for h in hands]
    fast_values = [evaluate_best_hand(h) for h in hands]
    _assert_same_total_order(naive_values, fast_values)
