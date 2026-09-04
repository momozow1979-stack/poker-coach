"""Verify the Python range-notation port matches the Dart implementation's
behavior (`lib/features/range_chart/domain/range_notation.dart`).
"""

from __future__ import annotations

from cfr_solver.poker.range_notation import expand


def test_plus_range_on_a_pair() -> None:
    assert expand("77+") == {"77", "88", "99", "TT", "JJ", "QQ", "KK", "AA"}


def test_plus_range_keeps_high_card_fixed() -> None:
    assert expand("A5s+") == {"A5s", "A6s", "A7s", "A8s", "A9s", "ATs", "AJs", "AQs", "AKs"}


def test_dash_range_same_gap_slides_the_whole_connector() -> None:
    assert expand("T9s-76s") == {"T9s", "98s", "87s", "76s"}


def test_dash_range_same_high_card_moves_the_kicker() -> None:
    assert expand("A5s-A2s") == {"A5s", "A4s", "A3s", "A2s"}


def test_dash_range_between_two_pairs() -> None:
    assert expand("QQ-88") == {"QQ", "JJ", "TT", "99", "88"}


def test_single_hands_and_commas() -> None:
    assert expand("AA, AKs, AKo") == {"AA", "AKs", "AKo"}


def test_ignores_blank_tokens_and_whitespace() -> None:
    assert expand(" AA ,, AKs") == {"AA", "AKs"}
