"""Solve BTN-open / BB-call single-raised pots on a few representative flops,
and export the BTN (aggressor) flop c-bet strategy aggregated to the 169
starting-hand classes, for the Flutter app to bundle.

Scope / honesty (see AGENTS.md rule 1, solver/BENCHMARKS.md):
- Ranges are this app's own BTN-open / BB-call ranges (realistic, wide).
- Each number is a direct readout of `CFRSolver.average_strategy()` — the
  solver's actual output, not a fabricated frequency. Because the ranges are
  wide, we do NOT run the (very expensive) exact-exploitability walk here; the
  export is labelled an approximate solve at N iterations, not a certified
  exact equilibrium.
- The flop decision is a single bet size (check vs bet), so the exported value
  per hand is a c-bet frequency in [0, 1].

Writes partial results after each board, so an interrupt keeps finished boards.
"""

from __future__ import annotations

import json
import time

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import card_str, parse_card

ITERATIONS = 12_000_000

# このアプリの BTN オープン / BB コール（vs BTN）レンジ（純粋部分）。
BTN_OPEN = (
    "22+,A2s+,K2s+,Q4s+,J6s+,T6s+,95s+,85s+,74s+,64s+,53s+,"
    "A2o+,K7o+,Q8o+,J8o+,T8o+,98o,87o,76o"
)
BB_CALL = (
    "22-88,A2s+,K2s+,Q5s+,J7s+,T7s+,96s+,85s+,75s+,64s+,53s+,"
    "A2o+,K8o+,Q9o+,J9o+,T9o,98o"
)

BOARDS = [
    ("a_high_dry", ("As", "7d", "2c")),
    ("wet_two_tone", ("9h", "8h", "5c")),
    ("paired", ("Jd", "Jc", "6s")),
    ("monotone", ("Ah", "Th", "6h")),
]

_RANK_ORDER = "AKQJT98765432"


def _class_code(cards: list[str]) -> str:
    r1, s1 = cards[0][0], cards[0][1]
    r2, s2 = cards[1][0], cards[1][1]
    if _RANK_ORDER.index(r1) <= _RANK_ORDER.index(r2):
        hi, lo = r1, r2
    else:
        hi, lo = r2, r1
    if hi == lo:
        return hi + lo
    return hi + lo + ("s" if s1 == s2 else "o")


def solve_board(spot_id: str, board_cards: tuple[str, ...]) -> dict:
    board = [parse_card(c) for c in board_cards]
    game = PostflopSubgame(
        board,
        hero_range_notation=BTN_OPEN,
        villain_range_notation=BB_CALL,
        bet_sizes=(2.5, 5.0, 7.5),
        max_wagers_per_round=1,
    )
    game.hero_combos = sorted(game.hero_combos)
    game.villain_combos = sorted(game.villain_combos)

    solver = CFRSolver(game, variant="cfr_plus", random_seed=1)
    print(
        f"[{spot_id}] {board_cards} hero={len(game.hero_combos)} "
        f"villain={len(game.villain_combos)} :: training {ITERATIONS:,}...",
        flush=True,
    )
    t0 = time.time()
    solver.train_external_sampling(ITERATIONS)
    elapsed = time.time() - t0
    avg = solver.average_strategy()
    print(
        f"[{spot_id}] trained in {elapsed / 60:.1f} min, "
        f"{solver.num_information_sets:,} info sets",
        flush=True,
    )

    # hero(BTN) の最初のフロップ決定（board のみ・まだ action 無し）。
    bucket: dict[str, list[float]] = {}
    for combo in game.hero_combos:
        key = game.information_set_key(
            (combo, None, tuple(board), "", "", ""), player=0
        )
        strat = avg.get(key)
        if strat is None:
            continue
        bet = float(strat.get("b", 0.0))
        code = _class_code([card_str(c) for c in combo])
        bucket.setdefault(code, []).append(bet)

    classes = {
        code: {
            "bet": round(sum(freqs) / len(freqs), 4),
            "combos": len(freqs),
        }
        for code, freqs in bucket.items()
    }
    return {
        "id": spot_id,
        "board": list(board_cards),
        "iterations": ITERATIONS,
        "classes": classes,
    }


def main() -> None:
    out_path = "solved_srp_btn_bb.json"
    spots = []
    for spot_id, board in BOARDS:
        spots.append(solve_board(spot_id, board))
        payload = {
            "matchup": "BTN open vs BB call (single-raised pot)",
            "hero": "BTN (aggressor)",
            "hero_range": BTN_OPEN,
            "villain_range": BB_CALL,
            "decision": "flop c-bet (check vs bet), hero acts first",
            "note": (
                "approximate solve (CFR+, external sampling) at the stated "
                "iterations; values are CFRSolver.average_strategy() readouts, "
                "aggregated to 169 hand classes as mean c-bet frequency."
            ),
            "spots": spots,
        }
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"[{spot_id}] wrote partial {out_path} ({len(spots)} spots)", flush=True)
    print("ALL DONE", flush=True)


if __name__ == "__main__":
    main()
