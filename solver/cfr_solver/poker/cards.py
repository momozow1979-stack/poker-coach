"""52-card deck and a 5-card poker hand evaluator.

Cards are plain ints 0..51: `rank(card) = card // 4` (0=deuce .. 12=ace),
`suit(card) = card % 4` (suit identity only matters for flushes/blockers,
never displayed). This is a from-scratch, minimal implementation — no
external poker library dependency — since all we need is: enumerate a
deck, and rank a 5-card hand.
"""

from __future__ import annotations

from collections import Counter
from itertools import combinations

RANK_SYMBOLS = "23456789TJQKA"
SUIT_SYMBOLS = "shdc"

DECK: list[int] = list(range(52))

# Hand categories, low to high — the first element of the comparison tuple
# `evaluate_5card` returns.
HIGH_CARD, ONE_PAIR, TWO_PAIR, TRIPS, STRAIGHT, FLUSH, FULL_HOUSE, QUADS, STRAIGHT_FLUSH = range(9)


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


def evaluate_5card(cards: list[int]) -> tuple[int, ...]:
    """Rank a 5-card hand. Higher tuple == better hand (plain tuple comparison).

    Handles the wheel (A-2-3-4-5) straight as 5-high, the standard poker
    exception where the ace also counts as rank 1.
    """
    if len(cards) != 5:
        raise ValueError(f"evaluate_5card expects exactly 5 cards, got {len(cards)}")

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
        elif unique_ranks == [12, 3, 2, 1, 0]:  # A-2-3-4-5, the wheel
            is_straight = True
            straight_high = 3

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


def evaluate_best_hand(cards: list[int]) -> tuple[int, ...]:
    """Best 5-card hand out of 5, 6, or 7 cards (hole cards + a partial or
    complete board). Degenerates to `evaluate_5card` when given exactly 5.
    """
    if len(cards) == 5:
        return evaluate_5card(cards)
    if len(cards) not in (6, 7):
        raise ValueError(f"evaluate_best_hand expects 5-7 cards, got {len(cards)}")
    return max(evaluate_5card(list(five)) for five in combinations(cards, 5))
