"""Solve BTN-open / BB-call single-raised pots on a few representative flops,
and export the BTN (aggressor) / BB (defender) strategy — flop, turn, river,
including facing-bet and facing-raise decisions — aggregated to the 169
starting-hand classes, for the Flutter app to bundle.

Scope / honesty (see AGENTS.md rule 1, solver/BENCHMARKS.md):
- Ranges are this app's own BTN-open / BB-call ranges (realistic, wide).
- Each number is a direct readout of `CFRSolver.average_strategy()` — the
  solver's actual output, not a fabricated frequency. Because the ranges are
  wide, we do NOT run the (very expensive) exact-exploitability walk here; the
  export is labelled an approximate solve at N iterations, not a certified
  exact equilibrium.
- `max_wagers_per_round=2` allows one bet + one raise per street (capped at
  a single raise — no re-raise), so "facing a raise" decisions are real
  solver output too, not invented.
- Turn/river strategy depends on the actual dealt card, not just the flop —
  a single information set does not represent "the turn" in general. Instead
  of covering all ~44/~43 possible turn/river cards (which would blow up both
  export size and the honesty of a 169-class aggregate — a flush-completing
  river plays nothing like a blank one), we solve the SAME already-computed
  tree but read out strategy at a handful of representative, deliberately
  distinct board textures per street:
    turn:  "blank" (lowest unrelated card), "over" (highest overcard),
           "texture" (flush-completer if the flop has 2+ of a suit, else a
           board-pairing card)
    river: "blank", "scare" (highest remaining card) — relative to the
           4-card board reached after the chosen turn card.
  This mirrors the existing "a few representative flops instead of every
  possible flop" design of this file (see BOARDS below) and is a free
  readout from the one already-planned training run — it does not require
  any additional solver iterations or GCP cost beyond what the original
  (flop-only) version of this script already spent/budgeted.
- Decision-point coverage per street (both players, 2 or 3 legal actions):
  hero's first action, villain facing hero's bet (can raise), hero facing
  villain's raise, villain checking back to open, hero facing villain's bet
  after checking (can raise), villain facing hero's raise. The turn/river
  readouts only cover the "checked through" line into that street (flop_a /
  turn_a == "xx") — the bet-called line into a later street is out of scope
  here, to keep export size and GCP time bounded; this is a real coverage
  gap, not an invented number filling the gap.
- Because the facing-raise lines are rarer branches of the same tree, their
  frequencies may be noisier (less converged) than the main first-action
  lines at the same iteration budget — flagged in the exported "note", not
  silently smoothed over.

Writes partial results after each board, so an interrupt keeps finished boards.
"""

from __future__ import annotations

import json
import os
import time
from collections import Counter

from cfr_solver.cfr import CFRSolver
from cfr_solver.games.postflop_subgame import PostflopSubgame
from cfr_solver.poker.cards import DECK, card_str, parse_card, rank_of, suit_of

ITERATIONS = 12_000_000
MAX_WAGERS_PER_ROUND = 2  # 1 bet + 1 raise per street (capped at one raise)

# このアプリの BTN オープン / BB コール（vs BTN）レンジ（純粋部分）。
# BTN_OPEN は range_definitions.dart の BTN オープン（raise のみ、mixed は含まない）と一致させる。
BTN_OPEN = (
    "22+,A2s+,K5s+,Q8s+,J8s+,T8s+,97s+,86s+,76s,65s,54s,"
    "A5o+,K8o+,Q9o+,J9o+,T9o"
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
    ("k_high_dry", ("Kh", "8s", "3c")),
    ("mid_connected", ("8c", "7d", "6h")),
    ("broadway", ("Qd", "Js", "Th")),
    ("ace_two_tone", ("Ah", "Kd", "4d")),
]

_RANK_ORDER = "AKQJT98765432"

# (node name, action tokens for the active street, acting player, legal actions)
# player 0 = hero (BTN, acts first on every street), player 1 = villain (BB).
_STREET_NODES: tuple[tuple[str, str, int, tuple[str, ...]], ...] = (
    ("hero_first", "", 0, ("x", "b")),
    ("villain_vs_check", "x", 1, ("x", "b")),
    ("hero_vs_bet_after_check", "xb", 0, ("f", "c", "b")),
    ("villain_vs_raise_after_check", "xbb", 1, ("f", "c")),
    ("villain_vs_bet", "b", 1, ("f", "c", "b")),
    ("hero_vs_raise", "bb", 0, ("f", "c")),
)


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


# -- representative turn/river card selection ---------------------------


def _dominant_suit(cards: tuple[int, ...]) -> int | None:
    """The suit with 2+ cards on `cards`, if any (two-tone/monotone board)."""
    suit, n = Counter(suit_of(c) for c in cards).most_common(1)[0]
    return suit if n >= 2 else None


def _blank_card(board: tuple[int, ...]) -> int:
    """Lowest card that pairs no board rank and isn't the flush suit."""
    board_ranks = {rank_of(c) for c in board}
    dominant = _dominant_suit(board)
    candidates = [
        c
        for c in DECK
        if c not in board and rank_of(c) not in board_ranks and suit_of(c) != dominant
    ]
    return min(candidates, key=rank_of)


def _overcard(board: tuple[int, ...]) -> int:
    """Highest card above the board's top rank (falls back to highest
    available card if the board already has an ace)."""
    board_ranks = {rank_of(c) for c in board}
    max_rank = max(board_ranks)
    candidates = [c for c in DECK if c not in board and rank_of(c) > max_rank]
    if not candidates:
        candidates = [c for c in DECK if c not in board]
    return max(candidates, key=rank_of)


def _texture_change_card(board: tuple[int, ...]) -> int:
    """A card that meaningfully changes the board's texture: completes the
    flush draw if the board is two-tone/monotone, otherwise pairs the board."""
    dominant = _dominant_suit(board)
    if dominant is not None:
        candidates = [c for c in DECK if c not in board and suit_of(c) == dominant]
        return min(candidates, key=rank_of)
    board_ranks = {rank_of(c) for c in board}
    candidates = [c for c in DECK if c not in board and rank_of(c) in board_ranks]
    if candidates:
        return min(candidates, key=rank_of)
    rest = sorted((c for c in DECK if c not in board), key=rank_of)
    return rest[len(rest) // 2]


def _turn_cards(flop_board: tuple[int, ...]) -> dict[str, int]:
    return {
        "blank": _blank_card(flop_board),
        "over": _overcard(flop_board),
        "texture": _texture_change_card(flop_board),
    }


def _river_cards(board4: tuple[int, ...]) -> dict[str, int]:
    return {
        "blank": _blank_card(board4),
        "scare": _overcard(board4),
    }


# -- readout --------------------------------------------------------------


def _bucket(
    combos,
    avg: dict,
    history_fn,
    actions: tuple[str, ...],
) -> dict:
    bucket: dict[str, dict[str, list[float]]] = {}
    for combo in combos:
        key = history_fn(combo)
        strat = avg.get(key)
        if strat is None:
            continue
        code = _class_code([card_str(c) for c in combo])
        entry = bucket.setdefault(code, {a: [] for a in actions})
        for a in actions:
            entry[a].append(float(strat.get(a, 0.0)))
    classes = {}
    for code, per_action in bucket.items():
        n = len(next(iter(per_action.values())))
        row = {a: round(sum(vals) / n, 4) for a, vals in per_action.items()}
        row["combos"] = n
        classes[code] = row
    return classes


def _street_nodes(
    game: PostflopSubgame,
    avg: dict,
    board: tuple[int, ...],
    flop_a: str,
    turn_a: str,
    river_a: str,
) -> dict:
    """Read out every `_STREET_NODES` decision point for the street whose
    history is currently empty-prefixed (`board` length tells us which of
    flop_a/turn_a/river_a is the "active" one the node tokens plug into)."""
    street = {"flop": 0, "turn": 1, "river": 2}[
        {3: "flop", 4: "turn", 5: "river"}[len(board)]
    ]
    out = {}
    for name, tokens, player, actions in _STREET_NODES:
        fa, ta, ra = flop_a, turn_a, river_a
        if street == 0:
            fa = tokens
        elif street == 1:
            ta = tokens
        else:
            ra = tokens
        combos = game.hero_combos if player == 0 else game.villain_combos

        def history_fn(combo, fa=fa, ta=ta, ra=ra, player=player):
            if player == 0:
                return game.information_set_key((combo, None, board, fa, ta, ra), player=0)
            return game.information_set_key((None, combo, board, fa, ta, ra), player=1)

        out[name] = _bucket(combos, avg, history_fn, actions)
    return out


def solve_board(spot_id: str, board_cards: tuple[str, ...]) -> dict:
    board_ids = [parse_card(c) for c in board_cards]
    game = PostflopSubgame(
        board_ids,
        hero_range_notation=BTN_OPEN,
        villain_range_notation=BB_CALL,
        bet_sizes=(2.5, 5.0, 7.5),
        max_wagers_per_round=MAX_WAGERS_PER_ROUND,
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

    board3 = tuple(board_ids)
    flop_nodes = _street_nodes(game, avg, board3, "", "", "")

    turns = {}
    for tex, tc in _turn_cards(board3).items():
        board4 = board3 + (tc,)
        turns[tex] = {
            "card": card_str(tc),
            "nodes": _street_nodes(game, avg, board4, "xx", "", ""),
        }

    rivers: dict[str, dict] = {}
    for tex, tc in _turn_cards(board3).items():
        board4 = board3 + (tc,)
        rivers[tex] = {}
        for rtex, rc in _river_cards(board4).items():
            board5 = board4 + (rc,)
            rivers[tex][rtex] = {
                "card": card_str(rc),
                "nodes": _street_nodes(game, avg, board5, "xx", "xx", ""),
            }

    return {
        "id": spot_id,
        "board": list(board_cards),
        "iterations": ITERATIONS,
        "flop": flop_nodes,
        "turns": turns,
        "rivers": rivers,
    }


def main() -> None:
    out_path = "solved_srp_btn_bb.json"
    spots = _download_existing(out_path)
    done_ids = {s["id"] for s in spots}
    for spot_id, board in BOARDS:
        if spot_id in done_ids:
            print(f"[{spot_id}] already solved (resumed), skipping", flush=True)
            continue
        spots.append(solve_board(spot_id, board))
        payload = {
            "matchup": "BTN open vs BB call (single-raised pot)",
            "hero": "BTN (aggressor)",
            "villain": "BB (defender)",
            "hero_range": BTN_OPEN,
            "villain_range": BB_CALL,
            "max_wagers_per_round": MAX_WAGERS_PER_ROUND,
            "decision": "flop/turn/river, hero acts first each street, 1 bet + 1 raise cap",
            "note": (
                "approximate solve (CFR+, external sampling) at the stated "
                "iterations; values are CFRSolver.average_strategy() readouts, "
                "aggregated to 169 hand classes as mean frequency per action. "
                "Turn/river nodes are read out only on the representative "
                "card textures listed per spot (not every possible card), and "
                "only along the checked-through line into that street. "
                "Facing-raise nodes are rarer branches of the same tree and "
                "may be noisier (less converged) than first-action nodes at "
                "the same iteration budget."
            ),
            "spots": spots,
        }
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"[{spot_id}] wrote partial {out_path} ({len(spots)} spots)", flush=True)
        # 盤ごとにアップロードする（1 回の実行が長時間に及ぶため、タイムアウトや
        # メンテナンス中断で打ち切られても、そこまでの盤の結果を失わないように）。
        _maybe_upload(out_path)
    print("ALL DONE", flush=True)


def _maybe_upload(path: str) -> None:
    """OUTPUT_GCS_URI（gs://bucket/name.json）が指定されていれば結果をアップロードする。

    Cloud Run Jobs ではジョブのサービスアカウントで自動認証される。ローカル実行時は
    環境変数が無いので何もしない（google-cloud-storage が無くても落ちない）。
    """
    uri = os.environ.get("OUTPUT_GCS_URI")
    if not uri or not uri.startswith("gs://"):
        return
    from google.cloud import storage  # type: ignore

    bucket_name, _, blob_name = uri[len("gs://") :].partition("/")
    client = storage.Client()
    client.bucket(bucket_name).blob(blob_name).upload_from_filename(path)
    print(f"uploaded {path} -> {uri}", flush=True)


def _download_existing(out_path: str) -> list[dict]:
    """OUTPUT_GCS_URI に前回までの出力があれば取得し、再開できるようにする。

    中断されたジョブを再実行したとき、既に解けている盤を再計算せずに済む。
    """
    uri = os.environ.get("OUTPUT_GCS_URI")
    if not uri or not uri.startswith("gs://"):
        return []
    from google.cloud import storage  # type: ignore

    bucket_name, _, blob_name = uri[len("gs://") :].partition("/")
    client = storage.Client()
    blob = client.bucket(bucket_name).blob(blob_name)
    if not blob.exists():
        return []
    blob.download_to_filename(out_path)
    with open(out_path, encoding="utf-8") as f:
        payload = json.load(f)
    spots = payload.get("spots", [])
    print(f"resumed: found {len(spots)} already-solved spot(s) in {uri}", flush=True)
    return spots


if __name__ == "__main__":
    main()
