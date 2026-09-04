"""Unit tests for `CFRSolver`'s flat-array information-set storage
(`BENCHMARKS.md`, "情報集合の保存方式") — separate from
`test_node_storage_regression.py`'s end-to-end bit-exact check, these probe
the storage internals directly (id assignment, action-set sharing, the
`STRIDE` guard) without needing a full game tree.
"""

from __future__ import annotations

import gc
import resource

import pytest

from cfr_solver.cfr import STRIDE, CFRSolver
from cfr_solver.games.kuhn import KuhnPoker


def _solver() -> CFRSolver:
    return CFRSolver(KuhnPoker())


def test_get_node_id_is_idempotent_for_the_same_key() -> None:
    solver = _solver()
    first = solver._get_node_id("J:", ["p", "b"])
    second = solver._get_node_id("J:", ["p", "b"])
    assert first == second
    assert solver.num_information_sets == 1


def test_different_keys_get_different_ids() -> None:
    solver = _solver()
    a = solver._get_node_id("J:", ["p", "b"])
    b = solver._get_node_id("Q:", ["p", "b"])
    assert a != b
    assert solver.num_information_sets == 2


def test_identical_action_sets_share_the_same_cached_action_set_object() -> None:
    solver = _solver()
    a = solver._get_node_id("J:", ["p", "b"])
    b = solver._get_node_id("Q:", ["p", "b"])
    # Two different information sets, same action vocabulary -> same
    # underlying _ActionSet instance, not merely an equal one. This is the
    # sharing the whole storage design depends on to stay cheap at scale.
    assert solver._action_set_for(a) is solver._action_set_for(b)


def test_action_set_beyond_stride_raises() -> None:
    solver = _solver()
    too_many_actions = [f"a{i}" for i in range(STRIDE + 1)]
    with pytest.raises(RuntimeError, match="STRIDE"):
        solver._get_node_id("some-key", too_many_actions)


def test_average_strategy_is_uniform_before_any_training() -> None:
    solver = _solver()
    solver._get_node_id("J:", ["p", "b"])
    avg = solver.average_strategy()
    assert avg == {"J:": {"p": 0.5, "b": 0.5}}


def test_num_information_sets_matches_index_size_after_training() -> None:
    solver = _solver()
    solver.train(50)
    assert solver.num_information_sets == len(solver.average_strategy())
    assert solver.num_information_sets > 0


def test_memory_per_information_set_stays_well_below_the_pre_refactor_design() -> None:
    """Regression tripwire, not a tight bound: the flat-array + shared
    action-set design measured ~192 B/information-set (`BENCHMARKS.md`,
    "情報集合の保存方式"), versus ~720 B/information-set for the original
    one-dict-of-dicts-per-node design. This asserts a generous 350 B/node
    ceiling — well above the measured value (room for platform/Python
    version noise) but well below the old design — so an accidental
    reversion back toward per-node Python objects gets caught here instead
    of only being noticed when a real wide-range run runs out of memory.
    """
    solver = _solver()
    n = 500_000

    gc.collect()
    before = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    for i in range(n):
        key = f"{i:014d}|xb|cc|f"
        solver._get_node_id(key, ["f", "c", "b"])
    gc.collect()
    after = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss

    bytes_per_node = (after - before) * 1024 / n
    assert bytes_per_node < 350, (
        f"measured {bytes_per_node:.1f} bytes/information-set, expected well under 350 "
        "(pre-refactor design measured ~720) — see BENCHMARKS.md"
    )
