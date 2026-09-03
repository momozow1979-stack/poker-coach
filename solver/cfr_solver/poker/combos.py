"""Expand 169-hand range codes into concrete 2-card combos, minus blockers."""

from __future__ import annotations

from .range_notation import parse_starting_hand

Combo = tuple[int, int]


def _rank_index(strength: int) -> int:
    """Rank strength (2..14) -> the 0..12 index used by `cards.py` (`card // 4`)."""
    return strength - 2


def combos_for_hand_code(code: str) -> list[Combo]:
    """All concrete card-id combos for one 169-hand code, e.g. `'AKs'` -> 4 combos."""
    high, low, shape = parse_starting_hand(code)
    hi_idx, lo_idx = _rank_index(high), _rank_index(low)

    if shape == "pair":
        cards = [hi_idx * 4 + s for s in range(4)]
        return [(cards[i], cards[j]) for i in range(4) for j in range(i + 1, 4)]

    if shape == "s":
        return [(hi_idx * 4 + s, lo_idx * 4 + s) for s in range(4)]

    # offsuit: any two different suits
    return [
        (hi_idx * 4 + s1, lo_idx * 4 + s2)
        for s1 in range(4)
        for s2 in range(4)
        if s1 != s2
    ]


def range_combos(hand_codes: set[str], blocked: set[int]) -> list[Combo]:
    """Every combo across `hand_codes`, excluding any combo touching a blocked card.

    Each returned combo is normalized to `(min, max)` card id order.
    """
    result: list[Combo] = []
    for code in hand_codes:
        for a, b in combos_for_hand_code(code):
            if a in blocked or b in blocked:
                continue
            result.append((a, b) if a < b else (b, a))
    return result
