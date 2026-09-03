"""Python port of the Flutter app's range notation parser.

Faithful port of `lib/features/range_chart/domain/range_notation.dart`'s
`RangeNotation.expand()`, so this solver can be handed the exact same
notation strings the app's range charts already use (`'22+, ATs+, KJo+'`
etc.) as the "arriving range" for a real spot, instead of inventing a
separate, potentially-inconsistent range representation. See
`RangeDefinitions` in `lib/features/range_chart/infrastructure/
range_definitions.dart` for the actual range strings used in the app.

Supported syntax (identical to the Dart version):
* `AA`, `AKs`, `AKo` — a single 169-hand code
* `77+` — that pair and every pair above it
* `A5s+` — same high card, kicker at or above that rank (same shape)
* `T9s-76s` — a band of connectors at the same gap
* `A5s-A2s` — same high card, kicker range
"""

from __future__ import annotations

RANK_ORDER = "AKQJT98765432"  # descending, matches CardRank.descending
RANK_STRENGTH = {symbol: 14 - i for i, symbol in enumerate(RANK_ORDER)}
RANK_SYMBOL = {strength: symbol for symbol, strength in RANK_STRENGTH.items()}
DESCENDING_STRENGTHS = list(range(14, 1, -1))  # 14 (A) down to 2


def parse_starting_hand(code: str) -> tuple[int, int, str]:
    """`'AKs'` -> `(14, 13, 's')`. Shape is `'pair'`, `'s'`, or `'o'`."""
    if len(code) not in (2, 3):
        raise ValueError(f"invalid hand code: {code!r}")
    r1 = RANK_STRENGTH[code[0].upper()]
    r2 = RANK_STRENGTH[code[1].upper()]
    if r1 == r2:
        return (r1, r2, "pair")
    if len(code) != 3:
        raise ValueError(f"suited/offsuit suffix required: {code!r}")
    shape = "s" if code[2].lower() == "s" else "o"
    high, low = (r1, r2) if r1 >= r2 else (r2, r1)
    return (high, low, shape)


def hand_code(high: int, low: int, shape: str) -> str:
    suffix = "" if shape == "pair" else shape
    return f"{RANK_SYMBOL[high]}{RANK_SYMBOL[low]}{suffix}"


def _expand_plus_range(base: str) -> set[str]:
    high, low, shape = parse_starting_hand(base)
    if shape == "pair":
        return {hand_code(r, r, "pair") for r in DESCENDING_STRENGTHS if r >= high}
    # e.g. A5s+ -> A5s, A6s, ..., AKs (high card fixed, kicker rises)
    return {hand_code(high, r, shape) for r in DESCENDING_STRENGTHS if low <= r < high}


def _expand_dash_range(token: str) -> set[str]:
    parts = token.split("-")
    if len(parts) != 2:
        raise ValueError(f"invalid range token: {token!r}")
    from_high, from_low, from_shape = parse_starting_hand(parts[0].strip())
    to_high, to_low, to_shape = parse_starting_hand(parts[1].strip())

    if from_shape == "pair" and to_shape == "pair":
        hi, lo = max(from_high, to_high), min(from_high, to_high)
        return {hand_code(r, r, "pair") for r in DESCENDING_STRENGTHS if lo <= r <= hi}

    if from_shape != to_shape:
        raise ValueError(f"mixed suited/offsuit in range token: {token!r}")
    shape = from_shape

    from_gap = from_high - from_low
    to_gap = to_high - to_low
    if from_gap == to_gap:
        # e.g. T9s-76s -> T9s, 98s, 87s, 76s (same gap, band of high cards)
        gap = from_gap
        top_high, bottom_high = max(from_high, to_high), min(from_high, to_high)
        return {
            hand_code(r, r - gap, shape)
            for r in DESCENDING_STRENGTHS
            if bottom_high <= r <= top_high
        }

    if from_high == to_high:
        # e.g. A5s-A2s -> A5s, A4s, A3s, A2s (high card fixed, kicker band)
        top, bottom = max(from_low, to_low), min(from_low, to_low)
        return {hand_code(from_high, r, shape) for r in DESCENDING_STRENGTHS if bottom <= r <= top}

    raise ValueError(f"unsupported range token: {token!r}")


def _expand_token(token: str) -> set[str]:
    if "-" in token:
        return _expand_dash_range(token)
    if token.endswith("+"):
        return _expand_plus_range(token[:-1])
    high, low, shape = parse_starting_hand(token)
    return {hand_code(high, low, shape)}


def expand(notation: str) -> set[str]:
    """Comma-separated range notation -> the set of 169-hand codes it covers."""
    hands: set[str] = set()
    for raw_token in notation.split(","):
        token = raw_token.strip()
        if not token:
            continue
        hands |= _expand_token(token)
    return hands
