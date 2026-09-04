# cfr-solver

AI Poker Coach 用の、ゲームに依存しない汎用 CFR / CFR+ ソルバー。

Dart/Flutter 製のアプリ本体（`../lib`）とは完全に独立した Python パッケージ。
将来、実際のポーカー局面（ヘッズアップのポストフロップ・プリフロップの多人数局面）を
解く際にも、ここにある `Game` インターフェース・`cfr.py`・`exploitability.py` を
そのまま再利用する前提で設計している。

## セットアップ

```bash
cd solver
pip install -e ".[dev]"
```

## テスト実行

```bash
pytest -v
```

## 中身

- `cfr_solver/games/game.py` — 任意の2人零和/N人ゼロサム展開形ゲームが実装する抽象インターフェース
- `cfr_solver/cfr.py` — CFR / CFR+ トレーナー（N人対応）
- `cfr_solver/exploitability.py` — best-response 計算・exploitability（2人・N人両対応）
- `cfr_solver/games/kuhn.py` — Kuhn Poker（検証用ベンチマーク①、理論値 -1/18 が既知）
- `cfr_solver/games/leduc.py` — Leduc Hold'em（検証用ベンチマーク②、CFR研究で標準的に使われる次のステップ）
- `cfr_solver/games/kuhn3p.py` — 3人版 Kuhn Poker（N人拡張の検証用。3人以上では単一のナッシュ均衡への収束は証明されないが、
  self-play で各プレイヤーの exploitability が下がっていくことを確認する）
- `cfr_solver/poker/` — 実際の52枚デッキ（5枚役評価器）と、Dart アプリの `RangeNotation`（
  `lib/features/range_chart/domain/range_notation.dart`）を Python に移植したレンジ表記パーサー
- `cfr_solver/games/flop_subgame.py` — 実データを使った最初の「本物の」ヘッズアップ・ポストフロップ局面
  （固定フロップ、実レンジ、1ベッティングラウンド）。フルレンジは Python のフルツリー CFR には
  大きすぎることを実測済み。現在はレンジを絞ったパイロット版のみ（詳細は `BENCHMARKS.md`）

収束の実測値・出典は `BENCHMARKS.md` に記録する。数値を先に決め打ちしてテストに書くことはしない。
