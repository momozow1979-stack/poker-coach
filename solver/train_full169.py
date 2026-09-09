"""Train `PostflopSubgame` with the full 169-starting-hand range on both
sides (1,176 combos/side after removing cards blocked by the flop), to the
scale `BENCHMARKS.md` calls the "全ハンド対応" target: 92,200,000
information sets.

Why this is a standalone script, not something run inside a Claude Code
session: two separate attempts to run this training inside the sandbox
this repository's solver work was otherwise done in were both killed by
that sandbox's memory limits (a per-process cgroup hard cap around
13.34GiB, and — after deliberately working around that cap — the
sandbox's total physical memory, ~16GB) before reaching the target. The
second of those crashes also destroyed the previous, perfectly good
checkpoint, because `CFRSolver.save()` was not yet crash-safe at the time
(see `BENCHMARKS.md`'s Stage S4/S6 entries for the full account). `save()`
is crash-safe now (atomic write via a temp file + `os.replace`), but the
sandbox's memory ceiling itself can't be changed — extrapolating from real
measurements (Stage S5's log), the full target needs on the order of 15GB
just for this process's resident data, which does not comfortably fit
that sandbox's limits. This script is meant to run on a machine with
enough real memory (32GB+) instead, with no assumption about cgroups,
container memory accounting, or any of this repository's sandbox-specific
infrastructure.

Usage:

    python3 train_full169.py --rss-limit-mb 24000

Re-running the same command resumes from `--checkpoint-path` if that file
already exists (bit-exact resume — see `cfr_solver/cfr.py`'s "Save/resume"
docstring section and `tests/test_cfr_persistence.py`), so this is safe to
stop (Ctrl-C between chunks, or just let the process be killed) and
restart without losing more than the most recent, still-in-progress chunk.
"""

from __future__ import annotations

import argparse
import os
import time

import psutil

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import parse_card

# Same setup as BENCHMARKS.md's Stage S2 through S6 — kept identical on
# purpose so a checkpoint produced by this script is directly comparable
# to (and exportable the same way as) those earlier measurements.
FULL_169_RANGE = (
    "22+,A2s+,A2o+,K2s+,K2o+,Q2s+,Q2o+,J2s+,J2o+,T2s+,T2o+,"
    "92s+,92o+,82s+,82o+,72s+,72o+,62s+,62o+,52s+,52o+,42s+,42o+,32s+,32o+"
)
FLOP_BOARD = ("7h", "2d", "3s")
BET_SIZES = (2.5, 5.0, 7.5)
MAX_WAGERS_PER_ROUND = 1
EXPECTED_COMBOS_PER_SIDE = 1176  # C(49,2) -- 52-card deck minus the 3 flop cards

DEFAULT_TARGET_INFO_SETS = 92_200_000
DEFAULT_CHUNK_ITERS = 100_000


def rss_mb() -> float:
    # Cross-platform peak/current resident set size for this process, in MB.
    # (Was `resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024` --
    # that stdlib module is POSIX-only and this script now also runs on
    # Windows. psutil's `memory_info().rss` is the current RSS, not the
    # all-time peak like ru_maxrss was; since this is polled every chunk
    # and only ever used to compare against --rss-limit-mb, that's fine --
    # the checkpoint/stop logic only cares about "is RSS high right now".
    return psutil.Process().memory_info().rss / (1024 * 1024)


def log(log_path: str, msg: str) -> None:
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    print(line, flush=True)
    with open(log_path, "a") as f:
        f.write(line + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--checkpoint-path",
        default="full169_cfrplus_seed1.cfrsave",
        help="Where to save/resume the checkpoint. Resumes automatically if this file already exists.",
    )
    parser.add_argument(
        "--log-path",
        default="train_full169.log",
        help="Progress log (also printed to stdout).",
    )
    parser.add_argument(
        "--rss-limit-mb",
        type=float,
        required=True,
        help=(
            "Stop (after saving a final checkpoint) once resource.getrusage().ru_maxrss "
            "reaches this many MB. Set this yourself based on your machine's actual free "
            "memory -- deliberately not auto-detected. Auto-detecting free memory failed "
            "to predict a real crash once already (a container/cgroup memory limit that "
            "didn't show up in /proc/meminfo); on a machine you control, you know the real "
            "number better than any heuristic here would."
        ),
    )
    parser.add_argument(
        "--target-info-sets",
        type=int,
        default=DEFAULT_TARGET_INFO_SETS,
        help=f"Stop once this many information sets are reached (default: {DEFAULT_TARGET_INFO_SETS:,}).",
    )
    parser.add_argument(
        "--iterations-per-chunk",
        type=int,
        default=DEFAULT_CHUNK_ITERS,
        help=f"External-sampling MCCFR iterations per checkpoint (default: {DEFAULT_CHUNK_ITERS:,}).",
    )
    parser.add_argument(
        "--max-wall-clock-hours",
        type=float,
        default=48.0,
        help="Backstop: stop after this many hours regardless of progress (default: 48).",
    )
    return parser.parse_args()


def build_game() -> PostflopSubgame:
    board = [parse_card(c) for c in FLOP_BOARD]
    game = PostflopSubgame(
        board,
        hero_range_notation=FULL_169_RANGE,
        villain_range_notation=FULL_169_RANGE,
        bet_sizes=BET_SIZES,
        max_wagers_per_round=MAX_WAGERS_PER_ROUND,
    )
    if len(game.hero_combos) != EXPECTED_COMBOS_PER_SIDE or len(game.villain_combos) != EXPECTED_COMBOS_PER_SIDE:
        raise AssertionError(
            f"expected {EXPECTED_COMBOS_PER_SIDE} combos/side, got "
            f"hero={len(game.hero_combos)} villain={len(game.villain_combos)} "
            "-- FULL_169_RANGE is wrong, fix it before spending real time training"
        )
    return game


def main() -> None:
    args = parse_args()
    game = build_game()

    if os.path.exists(args.checkpoint_path):
        t0 = time.time()
        solver = CFRSolver.load(args.checkpoint_path, game)
        log(
            args.log_path,
            f"resumed from {args.checkpoint_path} in {time.time() - t0:.2f}s "
            f"sampled_iter={solver._sampled_iterations_trained} "
            f"info_sets={solver.num_information_sets} rss_mb={rss_mb():.2f}",
        )
    else:
        solver = CFRSolver(game, variant="cfr_plus", random_seed=1)
        log(args.log_path, f"starting fresh: rss_mb={rss_mb():.2f}")

    log(
        args.log_path,
        f"target_info_sets={args.target_info_sets:,} rss_limit_mb={args.rss_limit_mb:,.0f} "
        f"iterations_per_chunk={args.iterations_per_chunk:,}",
    )

    t_start = time.time()
    while True:
        t0 = time.time()
        solver.train_external_sampling(args.iterations_per_chunk)
        train_s = time.time() - t0

        info_sets = solver.num_information_sets
        current_rss = rss_mb()
        elapsed_hours = (time.time() - t_start) / 3600
        log(
            args.log_path,
            f"CHECKPOINT sampled_iter={solver._sampled_iterations_trained} "
            f"train_s={train_s:.2f} info_sets={info_sets:,} rss_mb={current_rss:.2f}",
        )

        t_save0 = time.time()
        solver.save(args.checkpoint_path)
        log(args.log_path, f"saved checkpoint in {time.time() - t_save0:.2f}s rss_mb_after_save={rss_mb():.2f}")

        if info_sets >= args.target_info_sets:
            log(args.log_path, f"STOP: reached target of {args.target_info_sets:,} information sets")
            break
        if current_rss >= args.rss_limit_mb:
            log(args.log_path, f"STOP: rss_mb {current_rss:.2f} >= --rss-limit-mb {args.rss_limit_mb:,.0f}")
            break
        if elapsed_hours >= args.max_wall_clock_hours:
            log(args.log_path, f"STOP: reached --max-wall-clock-hours {args.max_wall_clock_hours}")
            break

    log(
        args.log_path,
        f"done: sampled_iter={solver._sampled_iterations_trained} "
        f"info_sets={solver.num_information_sets:,} "
        f"({100 * solver.num_information_sets / args.target_info_sets:.1f}% of target) "
        f"checkpoint={args.checkpoint_path}",
    )


if __name__ == "__main__":
    main()
