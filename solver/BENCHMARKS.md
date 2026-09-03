# ベンチマーク記録

このファイルには、実際に学習を走らせて観測した収束値だけを書く。
先に「これくらいのはず」と決め打ちした数値は書かない（原則1と同じ考え方）。

## Kuhn Poker

- 理論値（プレイヤー1の期待値）: **-1/18 ≈ -0.05556**（出典: Kuhn, 1950; Zinkevich et al., 2007
  "Regret Minimization in Games with Incomplete Information" の導入例としても使用）
- 実測値（CFR+、反復回数100,000、`cfr_solver` 実装、このマシンで実測）:
  - 学習時間: 約15.4秒
  - プレイヤー0の期待値: -0.055593（理論値との差: 0.000037）
  - exploitability: 0.000614

## Leduc Hold'em

- 参照した収束カーブ: Southey et al., 2005; Lanctot et al., 2009（Monte Carlo CFR 論文内のベンチマーク）;
  OpenSpiel `leduc_poker` 参照実装
- ゲーム木サイズ（このリポジトリの実装、`_simulate_round` の規約: 1ラウンドにつきベット+レイズ最大1回ずつ）:
  全履歴 9,457、終端履歴 5,520（`assert_game_is_well_formed` で確認済み）
- 実測値（CFR+、`cfr_solver` 実装、このマシンで実測。フルツリーの純Python実装のため
  100,000反復は実用時間を超えるとCI速度を優先して判断し、1,000〜5,000反復の範囲で確認）:
  - 1,000反復: exploitability = 0.029003（学習時間 約47.5秒）
  - 5,000反復: exploitability = 0.014839（累計学習時間 約236秒）
  - 反復を増やすと単調に下がる傾向を確認。テストの絶対閾値はこの実測値にマージンを乗せて設定する
    （`test_leduc_convergence.py` 参照）

## 3人版 Kuhn Poker

- 3人以上では CFR の self-play が単一のナッシュ均衡へ収束することは証明されない
  （参照: Abou Risk & Szafron, 2010 ほか、多人数 CFR 研究）。
  ここでは「収束の証明」ではなく「exploitability_per_player が学習とともに下がっていくか」を確認する。
- 実測値（CFR+、`cfr_solver` 実装、このマシンで実測。4枚デッキ・ベットサイズ1・レイズ無し）:
  - 1,000反復: 各プレイヤーの exploitability = [0.00486, 0.00572, 0.00311]（学習時間 約6.8秒）
  - 10,000反復: 各プレイヤーの exploitability = [0.00114, 0.00208, 0.00145]（累計学習時間 約65.0秒）
  - 全プレイヤーで単調に下がる傾向を確認
