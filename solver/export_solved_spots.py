"""Export flop-level hero decision frequencies from validated PostflopSubgame
solves into a JSON file the Flutter app can bundle as an asset.

Scope (deliberately narrow for this first integration — see
`docs/ai-prompts.md` and `BENCHMARKS.md`'s "don't fabricate" rule): only the
hero's FIRST flop decision (board = the 3-card flop, before any bet on this
street) is exported. Turn/river and villain-facing decisions are not
exported yet — extending coverage is future work once more boards/ranges are
solved. This keeps the exported file small and every number in it a direct,
verifiable readout of `CFRSolver.average_strategy()` for a spot whose
exploitability has already been measured (see `BENCHMARKS.md`), not a new
approximation.
"""

from __future__ import annotations

import json
import time

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import card_str, parse_card

FLOP_BOARD = [parse_card(c) for c in ("7h", "2d", "3s")]

SPOTS = [
    {
        "id": "aa_vs_kk_7h2d3s",
        "hero_range_notation": "AA",
        "villain_range_notation": "KK",
        "iterations": 1_000_000,
        "measured_exact_exploitability": 0.033,
    },
    {
        "id": "qq_plus_vs_tt_jj_7h2d3s",
        "hero_range_notation": "QQ+",
        "villain_range_notation": "TT-JJ",
        "iterations": 3_000_000,
        "measured_exact_exploitability": 0.03729,
    },
]

BET_SIZES_BB = (2.5, 5.0, 7.5)
MAX_WAGERS_PER_ROUND = 1


def export_spot(spec: dict) -> dict:
    game = PostflopSubgame(
        FLOP_BOARD,
        hero_range_notation=spec["hero_range_notation"],
        villain_range_notation=spec["villain_range_notation"],
        bet_sizes=BET_SIZES_BB,
        max_wagers_per_round=MAX_WAGERS_PER_ROUND,
    )
    solver = CFRSolver(game, variant="cfr_plus", random_seed=1)

    print(f"[{spec['id']}] training {spec['iterations']:,} iterations...", flush=True)
    t0 = time.time()
    solver.train_external_sampling(spec["iterations"])
    elapsed = time.time() - t0
    print(f"[{spec['id']}] done in {elapsed:.1f}s, {solver.num_information_sets:,} info sets", flush=True)

    avg = solver.average_strategy()

    entries = []
    for combo in game.hero_combos:
        # Hero's very first flop decision: board is exactly the 3-card flop,
        # no action taken on this street yet (flop_a == "").
        key = game.information_set_key((combo, None, tuple(FLOP_BOARD), "", "", ""), player=0)
        strategy = avg.get(key)
        if strategy is None:
            continue
        entries.append(
            {
                "hero_combo": [card_str(c) for c in combo],
                "strategy": {action: round(prob, 6) for action, prob in strategy.items()},
            }
        )

    return {
        "id": spec["id"],
        "board_flop": [card_str(c) for c in FLOP_BOARD],
        "hero_range_notation": spec["hero_range_notation"],
        "villain_range_notation": spec["villain_range_notation"],
        "bet_sizes_bb": list(BET_SIZES_BB),
        "max_wagers_per_round": MAX_WAGERS_PER_ROUND,
        "iterations_trained": spec["iterations"],
        "measured_exact_exploitability": spec["measured_exact_exploitability"],
        "entries": entries,
    }


def main() -> None:
    spots = [export_spot(spec) for spec in SPOTS]
    output = {
        "action_legend": {
            "x": "check",
            "b": "bet",
            "c": "call",
            "f": "fold",
        },
        "note": (
            "hero's first flop decision only (board = the 3-card flop, before "
            "any action this street). Every number here is a direct readout of "
            "CFRSolver.average_strategy() for a spot whose exploitability was "
            "measured (see solver/BENCHMARKS.md) — not a new estimate."
        ),
        "spots": spots,
    }
    out_path = "solved_spots.json"
    with open(out_path, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
