"""`solve_srp_btn_bb.py` の `MATCHUPS` レジストリの検証。

ここでのレンジ文字列は `lib/features/range_chart/infrastructure/
range_definitions.dart` から手で転記したもの（`mixedGroups` を除いた
`notationByAction` の純粋部分のみ、既存の BTN_OPEN/BB_CALL と同じ割り切り）。
手入力した以上、転記ミスは実際に起こりうるので、ここでは Dart 側の文字列と
一致していることを固定のテキストとして固定し、気づかず崩れないようにする。
"""

from __future__ import annotations

import importlib
import os

import pytest

import solve_srp_btn_bb as m


# Dart側 (`range_definitions.dart`) の各 `notationByAction` と一致させた、
# 期待されるレンジ文字列（カンマ後のスペースは無視して比較する）。
_EXPECTED_RANGES = {
    "btn_bb": {
        "oop_range": (
            "22-88,A2s+,K2s+,Q5s+,J7s+,T7s+,96s+,85s+,75s+,64s+,53s+,"
            "A2o+,K8o+,Q9o+,J9o+,T9o,98o"
        ),
        "ip_range": (
            "22+,A2s+,K5s+,Q8s+,J8s+,T8s+,97s+,86s+,76s,65s,54s,"
            "A5o+,K8o+,Q9o+,J9o+,T9o"
        ),
    },
    "hj_utg_6max": {
        "oop_range": "TT-77,AJs,KQs,KJs,QJs,JTs,T9s,98s,AQo",
        "ip_range": "77+,ATs+,KQs,KJs,QJs,JTs,T9s,98s,AQo+,KQo",
    },
    "co_hj_6max": {
        "oop_range": "99-66,ATs,KQs,KJs,QJs,JTs,T9s,98s,87s,AJo,KQo",
        "ip_range": "55+,ATs+,KTs+,QTs+,JTs,T9s,98s,87s,AJo+,KQo",
    },
    "btn_co": {
        "oop_range": "88-55,ATs,A9s,KJs,KTs,QJs,QTs,JTs,T9s,98s,87s,AJo,KJo",
        "ip_range": "44+,A8s+,KTs+,QTs+,J9s+,T9s,98s,87s,76s,ATo+,KJo+,QJo",
    },
    "sb_btn": {
        "oop_range": (
            "22-88,A2s+,K5s+,Q8s+,J8s+,T8s+,97s+,86s+,"
            "A2o+,K9o+,Q9o+,J9o+,T9o"
        ),
        "ip_range": (
            "22+,A2s+,K5s+,Q8s+,J8s+,T8s+,97s+,86s+,76s,65s,54s,"
            "A5o+,K8o+,Q9o+,J9o+,T9o"
        ),
    },
    "utg1_utg_9max": {
        "oop_range": "TT-88,AJs,KQs,KJs,QJs",
        "ip_range": "77+,ATs+,KQs,KJs,QJs,JTs,T9s,AQo+",
    },
    "mp_utg1_9max": {
        "oop_range": "TT-77,AJs,ATs,KQs,KJs,QJs,JTs",
        "ip_range": "66+,ATs+,KTs+,QJs,JTs,T9s,98s,AQo+,KQo",
    },
    "lj_mp_9max": {
        "oop_range": "99-66,ATs,KQs,KJs,QJs,JTs,T9s,KQo",
        "ip_range": "55+,ATs+,KTs+,QTs+,JTs,T9s,98s,87s,AJo+,KQo",
    },
    "hj_lj_9max": {
        "oop_range": "88-66,ATs,A9s,KJs,KTs,QJs,QTs,JTs,T9s,98s,KQo",
        "ip_range": "55+,ATs+,KTs+,QTs+,JTs,T9s,98s,87s,AJo+,KQo",
    },
    "co_hj_9max": {
        "oop_range": "88-55,ATs,A9s,KJs,KTs,QJs,QTs,JTs,T9s,98s,87s,AJo,KQo",
        "ip_range": "55+,ATs+,KTs+,QTs+,JTs,T9s,98s,87s,AJo+,KQo",
    },
}


def _normalize(notation: str) -> str:
    return notation.replace(" ", "")


def test_matchups_registry_has_exactly_the_expected_ids() -> None:
    assert set(m.MATCHUPS) == set(_EXPECTED_RANGES)


@pytest.mark.parametrize("matchup_id", sorted(_EXPECTED_RANGES))
def test_matchup_ranges_match_range_definitions_dart(matchup_id: str) -> None:
    expected = _EXPECTED_RANGES[matchup_id]
    actual = m.MATCHUPS[matchup_id]
    assert _normalize(actual["oop_range"]) == _normalize(expected["oop_range"])
    assert _normalize(actual["ip_range"]) == _normalize(expected["ip_range"])


@pytest.mark.parametrize("matchup_id", sorted(_EXPECTED_RANGES))
def test_every_matchup_has_required_metadata(matchup_id: str) -> None:
    entry = m.MATCHUPS[matchup_id]
    assert entry["oop_label"]
    assert entry["ip_label"]
    assert entry["matchup_label"]


def test_default_matchup_id_is_btn_bb_for_backward_compat() -> None:
    # MATCHUP_ID 環境変数が未指定のときの既定値。既存の本番データ
    # (solved_srp_btn_bb.json) はこのマッチアップで生成されているため、
    # これが変わると過去の運用手順のデフォルトが壊れる。
    assert m.MATCHUP_ID == "btn_bb"
    assert m.BTN_OPEN == m.MATCHUPS["btn_bb"]["ip_range"]
    assert m.BB_CALL == m.MATCHUPS["btn_bb"]["oop_range"]


def test_unknown_matchup_id_raises_on_import(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MATCHUP_ID", "does_not_exist")
    with pytest.raises(ValueError, match="unknown MATCHUP_ID"):
        importlib.reload(m)
    # 元に戻す（他のテストに影響しないよう、既定の btn_bb で再ロード）。
    monkeypatch.delenv("MATCHUP_ID", raising=False)
    importlib.reload(m)


def test_build_payload_reflects_requested_matchup_metadata() -> None:
    payload = m._build_payload([], matchup_id="sb_btn")
    assert payload["matchup_id"] == "sb_btn"
    assert payload["oop_position"] == m.MATCHUPS["sb_btn"]["oop_label"]
    assert payload["ip_position"] == m.MATCHUPS["sb_btn"]["ip_label"]
    assert payload["oop_range"] == m.MATCHUPS["sb_btn"]["oop_range"]
    assert payload["ip_range"] == m.MATCHUPS["sb_btn"]["ip_range"]


def test_build_payload_defaults_to_module_matchup_id() -> None:
    payload = m._build_payload([])
    assert payload["matchup_id"] == m.MATCHUP_ID
