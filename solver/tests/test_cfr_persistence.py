"""Bit-exact save/resume verification for `CFRSolver.save`/`CFRSolver.load`.

The whole point of this persistence layer (see `cfr.py`'s "Save/resume"
module-docstring section) is that stopping a training run, saving it, and
resuming it later in a brand-new process must produce output *identical* to
never having stopped at all — not "close", literally bit-for-bit identical,
matching this codebase's own established verification discipline for every
prior storage-layer change (`tests/test_node_storage_regression.py`,
`tests/test_cfr_storage.py`).

Every "resume" test below deliberately discards the original in-memory
solver object after saving and reconstructs a *fresh* one via `load` from
the file on disk, so the test actually exercises the save/load round-trip
rather than just continuing to train the same live object (which would
prove nothing about serialization).

The RNG-state restore is the single most likely place for a subtle bug (see
`cfr.py`'s docstring): re-seeding a fresh `Random(same_seed)` instead of
restoring the *exact* mid-stream state would silently replay already-
consumed "random" draws. Every `train_external_sampling` test here saves
mid-stream (not at iteration 0) specifically to catch that.
"""

from __future__ import annotations

import time

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.kuhn import KuhnPoker
from cfr_solver.games.kuhn3p import ThreePlayerKuhnPoker
from cfr_solver.games.leduc import LeducHoldem
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card


def _flop_board() -> list[int]:
    return [parse_card("2c"), parse_card("7d"), parse_card("Jh")]


# ---------------------------------------------------------------------------
# train_external_sampling: bit-exact resume, across three different games.
# ---------------------------------------------------------------------------


def test_kuhn_external_sampling_resume_is_bit_exact(tmp_path) -> None:
    solver_a = CFRSolver(KuhnPoker(), variant="cfr_plus", random_seed=1)
    solver_a.train_external_sampling(200)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(KuhnPoker(), variant="cfr_plus", random_seed=1)
    solver_b.train_external_sampling(100)
    path = tmp_path / "kuhn_mccfr.cfrsave"
    solver_b.save(str(path))
    del solver_b  # force the round-trip through disk, not the live object

    solver_c = CFRSolver.load(str(path), KuhnPoker())
    solver_c.train_external_sampling(100)

    assert solver_c.average_strategy() == reference
    assert solver_c._iterations_trained == 0
    assert solver_c._sampled_iterations_trained == 200


def test_leduc_external_sampling_resume_is_bit_exact(tmp_path) -> None:
    solver_a = CFRSolver(LeducHoldem(), variant="cfr_plus", random_seed=5)
    solver_a.train_external_sampling(300)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(LeducHoldem(), variant="cfr_plus", random_seed=5)
    solver_b.train_external_sampling(140)
    path = tmp_path / "leduc_mccfr.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), LeducHoldem())
    solver_c.train_external_sampling(160)

    assert solver_c.average_strategy() == reference


def test_kuhn3p_external_sampling_resume_is_bit_exact(tmp_path) -> None:
    solver_a = CFRSolver(ThreePlayerKuhnPoker(), variant="cfr_plus", random_seed=9)
    solver_a.train_external_sampling(300)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(ThreePlayerKuhnPoker(), variant="cfr_plus", random_seed=9)
    solver_b.train_external_sampling(123)
    path = tmp_path / "kuhn3p_mccfr.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), ThreePlayerKuhnPoker())
    solver_c.train_external_sampling(177)

    assert solver_c.average_strategy() == reference


# ---------------------------------------------------------------------------
# train (full-tree CFR): bit-exact resume, so this isn't sampling-specific.
# ---------------------------------------------------------------------------


def test_kuhn_full_tree_train_resume_is_bit_exact(tmp_path) -> None:
    solver_a = CFRSolver(KuhnPoker(), variant="cfr_plus")
    solver_a.train(400)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(KuhnPoker(), variant="cfr_plus")
    solver_b.train(150)
    path = tmp_path / "kuhn_full.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), KuhnPoker())
    solver_c.train(250)

    assert solver_c.average_strategy() == reference
    assert solver_c._iterations_trained == 400


def test_leduc_full_tree_train_resume_is_bit_exact(tmp_path) -> None:
    solver_a = CFRSolver(LeducHoldem(), variant="cfr_plus")
    solver_a.train(120)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(LeducHoldem(), variant="cfr_plus")
    solver_b.train(50)
    path = tmp_path / "leduc_full.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), LeducHoldem())
    solver_c.train(70)

    assert solver_c.average_strategy() == reference


def test_vanilla_cfr_variant_resume_is_bit_exact(tmp_path) -> None:
    """Same as above but `variant="cfr"` (not `cfr_plus`) — the regret
    accumulator is allowed to go negative under this variant, and the
    strategy-sum weighting rule differs, so this is a distinct code path
    worth its own bit-exact check."""
    solver_a = CFRSolver(KuhnPoker(), variant="cfr")
    solver_a.train(400)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(KuhnPoker(), variant="cfr")
    solver_b.train(180)
    path = tmp_path / "kuhn_vanilla.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), KuhnPoker())
    solver_c.train(220)

    assert solver_c.average_strategy() == reference


# ---------------------------------------------------------------------------
# Save/load API details.
# ---------------------------------------------------------------------------


def test_load_rejects_a_file_with_bad_magic_bytes(tmp_path) -> None:
    path = tmp_path / "not_a_save_file.cfrsave"
    path.write_bytes(b"definitely not a cfr solver save file" * 4)
    try:
        CFRSolver.load(str(path), KuhnPoker())
    except ValueError as exc:
        assert "not a CFRSolver save file" in str(exc)
    else:
        raise AssertionError("expected ValueError for a corrupt/foreign file")


def test_save_load_preserves_iteration_counters_and_variant_with_no_training(
    tmp_path,
) -> None:
    solver = CFRSolver(KuhnPoker(), variant="cfr", random_seed=3)
    path = tmp_path / "fresh.cfrsave"
    solver.save(str(path))

    loaded = CFRSolver.load(str(path), KuhnPoker())
    assert loaded.variant == "cfr"
    assert loaded._iterations_trained == 0
    assert loaded._sampled_iterations_trained == 0
    assert loaded.num_information_sets == 0
    assert loaded.average_strategy() == {}


def test_mixed_train_and_train_external_sampling_resume_is_bit_exact(tmp_path) -> None:
    """Exercises a solver whose `_action_sets` has accumulated real
    diversity and whose `_index`/`_regret`/`_strategy` reflect BOTH
    training methods before ever being saved — not just "immediately after
    construction with zero training" and not just one trainer in isolation.
    """
    solver_a = CFRSolver(LeducHoldem(), variant="cfr_plus", random_seed=13)
    solver_a.train(40)
    solver_a.train_external_sampling(150)
    solver_a.train(40)
    reference = solver_a.average_strategy()
    ref_action_sets = [tuple(a.actions) for a in solver_a._action_sets]

    solver_b = CFRSolver(LeducHoldem(), variant="cfr_plus", random_seed=13)
    solver_b.train(40)
    solver_b.train_external_sampling(150)
    # Mid-training save point: some info sets and action-set diversity
    # already accumulated, not a freshly-constructed solver.
    assert solver_b.num_information_sets > 0
    assert len(solver_b._action_sets) > 0
    path = tmp_path / "mixed.cfrsave"
    solver_b.save(str(path))
    del solver_b

    solver_c = CFRSolver.load(str(path), LeducHoldem())
    assert [tuple(a.actions) for a in solver_c._action_sets] == ref_action_sets
    solver_c.train(40)

    assert solver_c.average_strategy() == reference
    assert solver_c._iterations_trained == 80
    assert solver_c._sampled_iterations_trained == 150


# ---------------------------------------------------------------------------
# Real-game (PostflopSubgame) scale sanity check + honest timing.
# ---------------------------------------------------------------------------


def test_postflop_subgame_resume_is_bit_exact_and_timing_is_reported(tmp_path) -> None:
    """AA-vs-KK is a small, fast `PostflopSubgame` spot already used
    elsewhere in this codebase's regression tests (a real game, not a toy
    benchmark). This confirms save/load isn't accidentally Kuhn-specific
    AND reports actual save/load timing — see the printed output (run with
    `pytest -s` to see it) for whether `NodeIndex.items()` at this node
    count is already a meaningful fraction of `save`'s cost.
    """
    board = _flop_board()

    def _game() -> PostflopSubgame:
        return PostflopSubgame(
            board,
            hero_range_notation="AA",
            villain_range_notation="KK",
            bet_sizes=(2.5, 5.0, 7.5),
            max_wagers_per_round=2,
        )

    solver_a = CFRSolver(_game(), variant="cfr_plus", random_seed=21)
    solver_a.train_external_sampling(400)
    reference = solver_a.average_strategy()

    solver_b = CFRSolver(_game(), variant="cfr_plus", random_seed=21)
    solver_b.train_external_sampling(180)
    n_nodes = solver_b.num_information_sets
    path = tmp_path / "postflop_aa_vs_kk.cfrsave"

    t0 = time.perf_counter()
    solver_b.save(str(path))
    save_s = time.perf_counter() - t0
    del solver_b

    t0 = time.perf_counter()
    solver_c = CFRSolver.load(str(path), _game())
    load_s = time.perf_counter() - t0

    solver_c.train_external_sampling(220)
    assert solver_c.average_strategy() == reference

    file_bytes = path.stat().st_size
    print(
        f"\n[persistence timing] PostflopSubgame AA-vs-KK: {n_nodes} info sets, "
        f"save={save_s * 1000:.2f}ms load={load_s * 1000:.2f}ms "
        f"file={file_bytes / 1024:.1f}KiB "
        f"({(save_s + load_s) / max(n_nodes, 1) * 1e6:.3f}us/node combined)"
    )
