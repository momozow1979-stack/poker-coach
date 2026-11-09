"""Merge the per-board JSON parts written by `solve_srp_btn_bb.py` running in
Cloud Run Jobs task-parallel mode (`--tasks N`, one container per board) into
the single combined `solved_srp_btn_bb.json` the app expects.

Why this is a separate step: in task-parallel mode, each of the 8 containers
has no visibility into the others (that's the point — it gives each board its
own dedicated memory instead of sharing one container's limit, see
`solve_srp_btn_bb._run_as_cloud_run_task`), so none of them can safely
assemble the final combined file on their own. This script runs once after
all 8 tasks have finished and does that assembly, reusing the exact same
`_build_payload` used by the non-task-parallel code path so the output
schema is identical either way.

Usage:
    PARTS_GCS_PREFIX=gs://bucket/parts OUTPUT_GCS_URI=gs://bucket/solved_srp_btn_bb.json \
        python3 merge_solved_spots.py
"""

from __future__ import annotations

import json
import os
import sys

from solve_srp_btn_bb import BOARDS, _build_payload


def _list_and_download_parts(parts_prefix: str) -> dict[str, dict]:
    from google.cloud import storage  # type: ignore

    bucket_name, _, prefix = parts_prefix[len("gs://") :].partition("/")
    prefix = prefix.rstrip("/")
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    spots_by_id: dict[str, dict] = {}
    for blob in client.list_blobs(bucket, prefix=f"{prefix}/" if prefix else None):
        if not blob.name.endswith(".json"):
            continue
        spot = json.loads(blob.download_as_text())
        spots_by_id[spot["id"]] = spot
    return spots_by_id


def main() -> None:
    parts_prefix = os.environ.get("PARTS_GCS_PREFIX")
    out_uri = os.environ.get("OUTPUT_GCS_URI")
    if not parts_prefix or not parts_prefix.startswith("gs://"):
        print("PARTS_GCS_PREFIX (gs://bucket/prefix) is required", file=sys.stderr)
        sys.exit(1)
    if not out_uri or not out_uri.startswith("gs://"):
        print("OUTPUT_GCS_URI (gs://bucket/name.json) is required", file=sys.stderr)
        sys.exit(1)

    spots_by_id = _list_and_download_parts(parts_prefix)
    missing = [spot_id for spot_id, _ in BOARDS if spot_id not in spots_by_id]
    if missing:
        print(
            f"missing {len(missing)}/{len(BOARDS)} board part(s), not merging: {missing}",
            file=sys.stderr,
        )
        sys.exit(1)

    # BOARDSの順序で並べる(実行順ではなく、定義順に揃えて差分を読みやすくする)。
    spots = [spots_by_id[spot_id] for spot_id, _ in BOARDS]
    payload = _build_payload(spots)

    local_path = "solved_srp_btn_bb.json"
    with open(local_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"wrote {local_path} ({len(spots)} spots)")

    from google.cloud import storage  # type: ignore

    bucket_name, _, blob_name = out_uri[len("gs://") :].partition("/")
    storage.Client().bucket(bucket_name).blob(blob_name).upload_from_filename(local_path)
    print(f"uploaded {local_path} -> {out_uri}")


if __name__ == "__main__":
    main()
