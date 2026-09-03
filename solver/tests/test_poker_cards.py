"""Sanity checks for the 5-card hand evaluator and card parsing."""

from __future__ import annotations

from cfr_solver.poker.cards import card_str, evaluate_5card, parse_card


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
