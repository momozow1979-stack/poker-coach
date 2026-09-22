"""Solve additional flop textures for the same BTN-open / BB-call SRP, to enrich
the GTO flop viewer. Reuses solve_board() from solve_srp_btn_bb. Writes a
separate JSON (solved_srp_extra.json) so the original 4-board file is untouched;
merge the two `spots` lists into the app asset afterwards.
"""

from __future__ import annotations

import json

from solve_srp_btn_bb import BB_CALL, BTN_OPEN, solve_board

EXTRA_BOARDS = [
    ("k_high_dry", ("Kh", "8s", "3c")),
    ("mid_connected", ("8c", "7d", "6h")),
    ("broadway", ("Qd", "Js", "Th")),
    ("ace_two_tone", ("Ah", "Kd", "4d")),
]


def main() -> None:
    out_path = "solved_srp_extra.json"
    spots = []
    for spot_id, board in EXTRA_BOARDS:
        spots.append(solve_board(spot_id, board))
        payload = {
            "matchup": "BTN open vs BB call (single-raised pot)",
            "hero": "BTN (aggressor)",
            "hero_range": BTN_OPEN,
            "villain_range": BB_CALL,
            "decision": "flop c-bet (check vs bet), hero acts first",
            "spots": spots,
        }
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"[{spot_id}] wrote partial {out_path} ({len(spots)} spots)", flush=True)
    print("ALL DONE", flush=True)


if __name__ == "__main__":
    main()
