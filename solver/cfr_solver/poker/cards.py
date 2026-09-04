"""52-card deck and a 5-card poker hand evaluator.

Cards are plain ints 0..51: `rank(card) = card // 4` (0=deuce .. 12=ace),
`suit(card) = card % 4` (suit identity only matters for flushes/blockers,
never displayed). This is a from-scratch, minimal implementation — no
external poker library dependency — since all we need is: enumerate a
deck, and rank a 5-card hand.

`evaluate_5card` uses a small perfect-hash lookup scheme (in the spirit of
the well-known "Cactus Kev" 5-card evaluator technique — an original
from-scratch implementation of the same well-documented idea, not vendored
code) instead of a naive `Counter`/`sorted()`-per-call computation: this
function sits in the hottest path in the whole package (every showdown, in
every CFR training iteration and — far more expensive — every one of the
~44x43 turn/river outcomes `exploitability.best_response_value` enumerates
per combo pair; see `BENCHMARKS.md`, "高速ハンド評価器"). Two tiny tables
are built once at import time:

- `_STRAIGHT_HIGH_BY_BITMASK`: maps a 13-bit "which ranks are present" mask
  to the straight's high rank, for the 10 real straights plus the wheel
  (A-2-3-4-5, which ranks as 5-high, the standard poker exception — see
  `test_wheel_straight_ranks_as_five_high`).
- `_PATTERN_BY_PRIME_PRODUCT`: maps the product of each rank's assigned
  prime (one prime per rank, so by the fundamental theorem of arithmetic
  the product uniquely identifies the multiset of 5 ranks) to the hand's
  category and kicker order, for every rank-multiset that contains at
  least one repeated rank (pair/two-pair/trips/full-house/quads). A hand
  with 5 *distinct* ranks can never contain a repeated rank, so the two
  tables' domains never overlap and `evaluate_5card` uses one or the other
  based on whether all 5 ranks are distinct (a single `bit_count()` check).

Nothing in this package or its tests relies on the exact tuple *values*
`evaluate_5card`/`evaluate_best_hand` return, only their relative order
(`<`/`>`/`sorted()`) — see `test_poker_cards.py` — so this table-based
scheme is free to represent hands however is fastest, as long as ordering
matches the original naive implementation exactly (verified exhaustively
in `test_poker_cards.py`).
"""

from __future__ import annotations

from collections import Counter
from itertools import combinations, combinations_with_replacement

RANK_SYMBOLS = "23456789TJQKA"
SUIT_SYMBOLS = "shdc"

DECK: list[int] = list(range(52))

# Hand categories, low to high — the first element of the comparison tuple
# `evaluate_5card` returns.
HIGH_CARD, ONE_PAIR, TWO_PAIR, TRIPS, STRAIGHT, FLUSH, FULL_HOUSE, QUADS, STRAIGHT_FLUSH = range(9)

# One prime per rank (2..A). The product of 5 ranks' primes uniquely
# identifies that multiset of ranks (unique prime factorization), so it
# doubles as a perfect hash key for "which ranks, with which multiplicity".
_RANK_PRIME = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41)


def rank_of(card: int) -> int:
    return card // 4


def suit_of(card: int) -> int:
    return card % 4


def parse_card(text: str) -> int:
    """`'As'` -> card id. Inverse of `card_str`."""
    rank_symbol, suit_symbol = text[0].upper(), text[1].lower()
    return RANK_SYMBOLS.index(rank_symbol) * 4 + SUIT_SYMBOLS.index(suit_symbol)


def card_str(card: int) -> str:
    return f"{RANK_SYMBOLS[rank_of(card)]}{SUIT_SYMBOLS[suit_of(card)]}"


def _build_straight_table() -> dict[int, int]:
    """13-bit rank-presence bitmask -> straight high rank, for all 10 real
    straights (6-high through the broadway/ace-high) plus the wheel."""
    table: dict[int, int] = {}
    for top in range(4, 13):  # top=4 -> 6-high (ranks 0..4), top=12 -> broadway (ranks 8..12)
        bitmask = 0
        for r in range(top - 4, top + 1):
            bitmask |= 1 << r
        table[bitmask] = top
    wheel_bitmask = (1 << 12) | (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
    table[wheel_bitmask] = 3  # A-2-3-4-5 ranks as 5-high, not ace-high
    return table


def _build_pattern_table() -> dict[int, tuple[int, tuple[int, ...]]]:
    """Prime product of a 5-rank multiset -> (category, kicker-ordered ranks),
    for every multiset that contains at least one repeated rank. A 5-distinct
    -rank hand is handled separately in `evaluate_5card` (it can never reach
    this table, since its ranks have no repeats to hash on)."""
    table: dict[int, tuple[int, tuple[int, ...]]] = {}
    for ranks in combinations_with_replacement(range(13), 5):
        counts = Counter(ranks)
        if len(counts) == 5:
            continue  # all distinct — not this table's job (see module docstring)
        by_count_then_rank = sorted(counts.items(), key=lambda kv: (-kv[1], -kv[0]))
        count_pattern = tuple(count for _, count in by_count_then_rank)
        ordered_ranks = tuple(rank for rank, _ in by_count_then_rank)
        category = {
            (4, 1): QUADS,
            (3, 2): FULL_HOUSE,
            (3, 1, 1): TRIPS,
            (2, 2, 1): TWO_PAIR,
            (2, 1, 1, 1): ONE_PAIR,
        }.get(count_pattern)
        if category is None:
            # A pattern like (5,) — 5 of the same rank — cannot occur in a
            # real hand (each rank has only 4 suits), but
            # `combinations_with_replacement` doesn't know that; skip it.
            continue
        product = 1
        for r in ranks:
            product *= _RANK_PRIME[r]
        table[product] = (category, ordered_ranks)
    return table


_STRAIGHT_HIGH_BY_BITMASK = _build_straight_table()
_PATTERN_BY_PRIME_PRODUCT = _build_pattern_table()


def evaluate_5card(cards: list[int]) -> tuple[int, ...]:
    """Rank a 5-card hand. Higher tuple == better hand (plain tuple comparison).

    Handles the wheel (A-2-3-4-5) straight as 5-high, the standard poker
    exception where the ace also counts as rank 1.
    """
    if len(cards) != 5:
        raise ValueError(f"evaluate_5card expects exactly 5 cards, got {len(cards)}")

    ranks = [rank_of(c) for c in cards]
    suit0 = suit_of(cards[0])
    is_flush = all(suit_of(c) == suit0 for c in cards[1:])

    rank_bits = 0
    for r in ranks:
        rank_bits |= 1 << r

    if rank_bits.bit_count() == 5:
        # 5 distinct ranks: no pair/trips/etc. is possible, only
        # straight and/or flush (independently) or plain high card.
        straight_high = _STRAIGHT_HIGH_BY_BITMASK.get(rank_bits)
        ordered_ranks = tuple(sorted(ranks, reverse=True))
        if straight_high is not None and is_flush:
            return (STRAIGHT_FLUSH, straight_high)
        if is_flush:
            return (FLUSH, *ordered_ranks)
        if straight_high is not None:
            return (STRAIGHT, straight_high)
        return (HIGH_CARD, *ordered_ranks)

    # A rank repeats, so (as in real poker) this hand cannot be a flush
    # (two cards of the same rank always have different suits) or a
    # straight (which needs 5 distinct ranks) — look up the pattern directly.
    product = 1
    for r in ranks:
        product *= _RANK_PRIME[r]
    category, ordered_ranks = _PATTERN_BY_PRIME_PRODUCT[product]
    return (category, *ordered_ranks)


def evaluate_best_hand(cards: list[int]) -> tuple[int, ...]:
    """Best 5-card hand out of 5, 6, or 7 cards (hole cards + a partial or
    complete board). Degenerates to `evaluate_5card` when given exactly 5.
    """
    if len(cards) == 5:
        return evaluate_5card(cards)
    if len(cards) not in (6, 7):
        raise ValueError(f"evaluate_best_hand expects 5-7 cards, got {len(cards)}")
    return max(evaluate_5card(list(five)) for five in combinations(cards, 5))
