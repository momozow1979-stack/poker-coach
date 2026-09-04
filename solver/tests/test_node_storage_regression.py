"""Exact-equality regression gate for the `_Node` storage refactor
(`BENCHMARKS.md`, "情報集合の保存方式" section — `__slots__` -> shared
action tuples -> `array.array` -> flat Structure-of-Arrays).

None of those stages reorder a single floating-point operation — they only
change what physically holds the same numbers (a dict vs. a slice of a flat
`array.array`). So unlike the tolerance-based convergence tests elsewhere in
this package, this one demands bit-for-bit equality against reference
values captured from the pre-refactor implementation and frozen into
`fixtures/pre_refactor_reference.json`. Any storage change that produces
even a single differently-rounded float here is a real bug (a reordered
sum, a wrong action-to-slot mapping, ...), not acceptable "close enough"
noise.
"""

from __future__ import annotations

import json
from pathlib import Path

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.kuhn import KuhnPoker
from cfr_solver.games.leduc import LeducHoldem

FIXTURE_PATH = Path(__file__).parent / "fixtures" / "pre_refactor_reference.json"


def _reference() -> dict[str, dict[str, dict[str, float]]]:
    return json.loads(FIXTURE_PATH.read_text())


def test_kuhn_full_tree_cfr_plus_matches_pre_refactor_reference_exactly() -> None:
    solver = CFRSolver(KuhnPoker(), variant="cfr_plus")
    solver.train(2000)
    assert solver.average_strategy() == _reference()["kuhn_cfr_plus_2000"]


def test_kuhn_mccfr_matches_pre_refactor_reference_exactly() -> None:
    solver = CFRSolver(KuhnPoker(), variant="cfr_plus", random_seed=42)
    solver.train_external_sampling(3000)
    assert solver.average_strategy() == _reference()["kuhn_mccfr_3000_seed42"]


def test_leduc_full_tree_cfr_plus_matches_pre_refactor_reference_exactly() -> None:
    solver = CFRSolver(LeducHoldem(), variant="cfr_plus")
    solver.train(500)
    assert solver.average_strategy() == _reference()["leduc_cfr_plus_500"]
