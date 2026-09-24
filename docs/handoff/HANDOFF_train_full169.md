# 引き継ぎ書: 全169ハンド対応CFR学習をローカルPCで実行する

## これは何のタスクか

`poker-coach`リポジトリのポーカーCFRソルバーで、全169スターティングハンド
レンジ（ヒーロー・ヴィラン双方1,176コンボ）でのCFR学習を、目標
9,220万情報集合まで到達させる。

**これはクラウドのサンドボックス内では実行できない。** 実際に2回試行し、
2回ともメモリ上限でクラッシュした（サンドボックスのcgroup上限は約
13.34GiB、システム全体でも約16GB。実測からの外挿では目標達成に
最低でも約15.5GBのメモリが必要で、安全マージンが無い）。2回目の
クラッシュでは、当時`save()`が非アトミック書き込みだったため、直前の
正常なチェックポイント（78,596,980情報集合、目標の約85.4%）まで
巻き添えで失われ、復元不能になった（バックアップなし）。

そのため、このタスクは**ユーザー本人のPC（Windows、32GB RAM、
Intel Core Ultra 7 155U）上で、Claude Code Remoteのクラウドセッション
を介さず直接実行する**ことになっている。あなたがそのローカル実行を
担当するセッションである。

## リポジトリとブランチ

```
https://github.com/momozow1979-stack/poker-coach.git
```

学習スクリプト`solver/train_full169.py`は、PR #34
（`feat/solver-standalone-training-script` → `main`）で追加された。
このPRは**あなたの作業開始時点でまだmainにマージされていない可能性が
ある**（クラウド側のセッションがCI確認・マージ作業を進行中）。

- もし`main`に`solver/train_full169.py`が存在すれば、`main`をそのまま使う。
- 存在しなければ、`feat/solver-standalone-training-script`ブランチを
  checkoutして使う（スクリプトの内容はこのブランチとmargeされた後の
  mainとで変わらない — 学習を始めるために後からmainへの切り替えを
  待つ必要はない）。

## セットアップ手順（WSL2 / Ubuntu想定）

```bash
# WSL2が未導入なら、Windows PowerShell（管理者）で先に:
#   wsl --install
# （インストール後に再起動が必要な場合がある）

sudo apt update && sudo apt install -y build-essential python3 python3-pip python3-venv
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

git clone https://github.com/momozow1979-stack/poker-coach.git
cd poker-coach

# solver/train_full169.py が無ければブランチを切り替える
ls solver/train_full169.py || git checkout feat/solver-standalone-training-script

cd solver
pip install -e ".[dev]"   # maturinがRust拡張(cfr_solver._native)を自動ビルドする
```

## 実行コマンド

```bash
# --rss-limit-mb は「このPCの実際の空きメモリ」から自分で決める値。
# 32GB搭載・WSL2既定(ホストの約80%=約24GB使用可)を前提に、
# 安全マージンを取って24000(24GB)を推奨する。
# 他のアプリでメモリを多く使っている場合はもっと低い値にすること。
nohup python3 train_full169.py --rss-limit-mb 24000 > train.log 2>&1 &

# 進捗確認（Ctrl-Cで見るのをやめても学習プロセス自体は止まらない）
tail -f train.log
```

- 目標: `info_sets`が92,200,000に到達したら自動停止（ログに
  `STOP: reached target of 92,200,000 information sets`と出る）。
- `--rss-limit-mb`に達した場合も、その時点の状態を安全に保存して停止する
  （`STOP: rss_mb ... >= --rss-limit-mb ...`）。どちらで止まっても
  チェックポイントファイルは有効な状態で保存されている。
- チェックポイントは`--checkpoint-path`未指定時、
  `solver/full169_cfrplus_seed1.cfrsave`に保存される。
- **再開は自動**: 同じコマンドを再実行すれば、既存の
  `full169_cfrplus_seed1.cfrsave`から続きを学習する（bit-exact resume）。
  途中でPCを再起動した場合やプロセスが落ちた場合も、同じコマンドで
  再実行すればよい。
- 想定所要時間: サンドボックスでの小規模実測（数千反復・数万情報集合
  規模）からの参考値のみで、9,220万情報集合規模の総所要時間は
  未実測。数時間〜数日かかる可能性がある前提で、`nohup`でバック
  グラウンド実行し、放置してよい設計になっている。

## このセッション（ローカル）がやること／やらないこと

**やること:**
- 上記セットアップと学習の実行、進捗の監視のみ。
- 学習が停止したら（目標到達 or RSS上限到達）、`train.log`の最後の行
  （`done: ...`）を確認し、ユーザーに完了を報告する。

**やらないこと（クラウド側セッションの担当）:**
- コードの変更、コミット、PR作成、`main`へのマージ作業は一切不要。
  このタスクは既存の`train_full169.py`をそのまま実行するだけ。
- 学習結果（チェックポイントファイル・ログ）を`solved_spots.json`へ
  統合する作業は、**結果をユーザーがクラウド側のClaude Codeセッションに
  渡した後**に行う。ローカル側でこの統合作業をする必要はない。

## 完了後にユーザーがすること

学習が停止したら（途中経過でも、目標到達でも）、生成された
`solver/full169_cfrplus_seed1.cfrsave`ファイルと`train.log`を、
クラウド側のClaude Codeセッションに渡す（アップロード等）。そちらで
`assets/solved_spots/solved_spots.json`への統合・検証・PR作成を行う。
