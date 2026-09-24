# 引き継ぎ書: poker-coach プロジェクト全体（2026-09-08時点）

これは、これまでこのプロジェクトを担当していたClaude Codeセッション
（クラウド版）から、別の新しいセッションへの完全な引き継ぎ書です。
新しいセッションはこの会話の履歴を一切持っていない前提で、この文書
だけで作業を再開できるように書いています。

## 0. まず読むべきファイル（このリポジトリ内、常に最新）

新しいセッションは、作業開始時に必ず以下を読むこと。この引き継ぎ書は
「今何が起きているか」の要約であり、恒久的なルールは常にリポジトリ内の
これらのファイルが正（このファイルが古くなってもリポジトリ側が正しい）:

- **`AGENTS.md`**（リポジトリ直下）— AIエージェント向けの絶対厳守ルールと、
  過去に踏んだ地雷の一覧。**最優先で読むこと。**
- **`README.md`**（リポジトリ直下）— アプリの仕様・実装状況・技術構成。
- **`solver/BENCHMARKS.md`** — CFRソルバー開発の全実測記録（Stage 1〜S7まで）。
  数値は一切捏造せず、実測した事実だけを記録する方針で一貫して書かれている。
  ソルバー関連の作業をする前に必ず目を通すこと。
- **`solver/README.md`** — ソルバーパッケージの構成・セットアップ・テスト実行方法。
- **`docs/ai-prompts.md`** — AIハンドレビュー（Phase 6、未着手）のプロンプト設計。
- **`supabase/schema.sql`** / **`supabase/migrations/`** — DBスキーマとマイグレーション。

**重要な注意**: 以下の「10. 全タスク履歴」は、旧セッションのタスク管理ツール
（このセッション固有の状態）の中身をそのまま書き写したものです。新しい
セッションが持つタスク管理機能とは別物で、自動的には引き継がれないため、
ここに全件テキストで残しています。新しいセッションで作業を続ける際は、
このリストを自分のタスク管理に転記するか、そのまま参照して進捗把握に使うこと。

## 1. プロジェクト概要

`poker-coach`は、初心者〜中級者向けNo-Limit Texas Hold'em学習アプリ
（Flutter、iOS/Android/Web）+ 独自CFRソルバー（Python/Rust、
`solver/`ディレクトリ）の2本立て。フロントエンドはSupabaseを
バックエンドに使う。ユーザー（もも さん、momo.yoko@bywill.co.jp）は
日本語話者。**すべてのコミュニケーションは日本語で行う。**

## 2. 絶対に守るべきルール（AGENTS.mdの要約 + このセッションで確立した運用ルール）

1. **GTOの頻度やEVの数値を捏造しない。** ソルバーの実計算結果が無い数値は
   絶対に出さない。ベンチマークやテスト結果も同様——実測していない
   数字を「だいたいこのくらい」と書かない。
2. OpenAI APIキーをクライアントに埋め込まない（Edge Function経由のみ）。
3. `sb_secret_`で始まるSupabaseの秘密鍵を絶対に使わない
   （`sb_publishable_`は公開鍵なのでOK）。
4. 解説文は初心者にもわかる日本語で。「GTOだから」で済ませない。
5. 破壊的操作（force push、DB直接操作、履歴書き換え、ファイル削除など）は
   必ず先にユーザーに確認する。
6. **作業はfeatureブランチ → draft PR → CI green → マージの流れを厳守。
   `main`に直接コミットしない。**
7. コミットメッセージ末尾:
   ```
   Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
   Claude-Session: https://claude.ai/code/session_01WynDSW8mfeh7yHM7xw5YPr
   ```
   （新しいセッションで作業する場合、`Claude-Session`のURLは新しいセッション
   自身のものに置き換えること——これは旧セッションのIDなので、
   新セッションがそのまま複製してはいけない）
8. PR本文末尾:
   ```
   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
9. PR作成後は必ず`subscribe_pr_activity`でCI監視を開始し、CIが落ちたら
   直す。グリーンになったらdraft解除してマージ、`unsubscribe_pr_activity`、
   ローカル`main`を`git fetch && git merge --ff-only origin/main`で同期。
10. **メモリ・性能の測定は`resource.getrusage(resource.RUSAGE_SELF).ru_maxrss`
    をプロセス起動直後と操作後の同一プロセス内で比較する**、という
    厳密な方法で行う（このセッションで一貫して使った手法。詳細は
    `solver/BENCHMARKS.md`の各Stageの記述を参照）。

## 3. 現在の状態（このセッションで完了した作業）

### 3-1. Google Sign-In（完了）
Flutter側にGoogle Sign-In実装済み（PR #28、マージ済み）。Supabase・
Google Cloud Console側の設定（OAuthクライアントをWeb applicationタイプに、
Site URLを正しいデプロイ先に、等）もユーザー側で完了済み。動作確認済み。

### 3-2. ソルバーのRust移植・全169ハンド対応基盤（完了、PR #29〜#34マージ済み）

順に:
- PR #29: 散らばっていたRustソルバー書き換え作業（`solver/native/`）を
  初めて`main`に統合。
- PR #30: `export_solved_spots.py`をRust実装の`exploitability_parallel_native`
  で実際に計算するように変更（捏造していたハードコード定数を除去）。
- PR #31: `_equity_cache`をRust実装の`EquityCache`に置き換え（メモリ
  347.2 B/entry → 65.7 B/entry、約5.3倍圧縮）。
- PR #32: `CFRSolver.save()`をアトミック書き込み（一時ファイル→`os.replace`）
  に修正。**理由: 実際にクラッシュで前のチェックポイントごと失われる
  事故が起きたため**（次項参照）。
- PR #33: `save()`内の`.tobytes()`によるメモリコピー（約1.79GB相当の
  一時コピー）を除去し、`memoryview`ベースのゼロコピー書き込みに変更。
- PR #34: `solver/train_full169.py`（下記4節）を追加。**このセッションが
  最後に行った作業。マージ済み（もしくはマージ直前、下記参照）。**

### 3-3. 重大インシデント: 全169ハンド学習でのチェックポイント消失（発生済み、教訓化済み）

全169ハンドレンジ（ヒーロー・ヴィラン各1,176コンボ）でのCFR学習を、
このクラウドのサンドボックス内で完走させようとして**2回失敗した**:

1. 1回目: cgroupメモリ上限（約13.34GiB）を回避してシステム全体の
   物理メモリ（約16GB）まで使ったが、71,619,726情報集合
   （目標9,220万件の約77.7%）でシステム全体のOOM killerに強制終了。
2. 2回目（equity cacheのRust化後の再開）: 78,704,243情報集合
   （約85.4%）まで到達したが、cgroup上限で再度強制終了。
   **しかも当時`save()`が非アトミックだったため、直前の正常な
   チェックポイント（78,596,980件）まで巻き添えで破壊され、
   復元不能になった。バックアップは存在しなかった。**

この事故を受けて`save()`をアトミック化（PR #32）・コピー除去（PR #33）
した。**しかしこのサンドボックス自体の物理メモリ上限（cgroup上限
約13.34GiB、システム全体でも約16GB）は変更できない。** 実測からの
外挿（Stage S5の実測: 78,596,980情報集合の時点で保存後RSS
13,566.28MB = 180.99 B/情報集合）では、目標9,220万件には
**最低でも約15.5GBのメモリが必要**——このサンドボックスでは
安全マージンがほぼ無い。

**結論（ユーザー承認済み）: 全169ハンド対応の実学習は、このクラウド
セッション内では二度と試みない。** ユーザー本人のPC（Windows、
32GB RAM、Intel Core Ultra 7 155U、既に保有）で、WSL2経由で直接
実行する。

## 4. 現在進行中のタスク: 全169ハンド対応CFR学習の外部実行

### 4-1. 実装済みのもの

`solver/train_full169.py`（PR #34でmainにマージ済み——マージ状況は
下記4-3で必ず再確認すること）:

- 全169ハンドレンジ・ボード`7h,2d,3s`・ベットサイズ`(2.5, 5.0, 7.5)`・
  `max_wagers_per_round=1`——Stage S2〜S6と完全に同一の設定。
- `--checkpoint-path`で指定したファイルが既にあれば自動再開
  （bit-exact resume）。
- `--rss-limit-mb`（必須引数、自動検出はしない——理由:
  `/proc/meminfo`ベースの自動検出は、cgroup制限を検出できず
  実際に1回外れた実績があるため、あえて自動化していない）
  に達するか、`--target-info-sets`（デフォルト9,220万）に達するまで
  学習を続け、安全に停止する。

このサンドボックス内では小規模（数千反復規模）でのみ動作確認済み
（引数パース・チェックポイント保存・再開・ログ出力が正しく動くこと
を確認済み）。**大規模な実本番実行はこのサンドボックスでは一度も
行っていない。**

### 4-2. ユーザーのPC側で今後やること

1. WSL2（Ubuntu）環境を用意（未導入なら`wsl --install`）。
2. `build-essential`, `python3`, `pip`, `venv`をapt installし、
   rustupでRustツールチェインを導入。
3. リポジトリをclone、`solver/`ディレクトリで
   `pip install -e ".[dev]"`（maturinがRust拡張を自動ビルド）。
4. `nohup python3 train_full169.py --rss-limit-mb 24000 > train.log 2>&1 &`
   で開始。32GB搭載・WSL2既定のメモリ上限（ホストの約80%）を前提に
   24000(MB)を目安値として提示済み——実際の空き容量に応じて
   ユーザー自身が調整してよい。
5. 学習が停止したら（目標到達、またはRSS上限到達で自動停止）、
   生成された`.cfrsave`ファイルと`train.log`を、**ユーザー自身が
   手動でGoogle Driveにアップロード**する。

（この4-1・4-2の内容は`HANDOFF_train_full169.md`という別ファイルに
既に詳しく書き出し済みで、ユーザーに渡してある。内容はこの節と
重複するが、より詳しい実行コマンド付き。）

### 4-3. 新しいセッションが最初に確認すべきこと

- PR #34が実際に`main`にマージ済みか、GitHub上で確認する
  （`mcp__github__pull_request_read` method `get`、
  owner=`momozow1979-stack`, repo=`poker-coach`, pullNumber=34）。
  もし未マージなら、CIステータス（`get_check_runs`）を確認し、
  グリーンならマージまで完了させる。
- ローカルの`main`ブランチが最新化されているか
  （`git fetch origin main && git log origin/main -1`）。

## 5. チェックポイント受け取り後にやるべきこと（まだ未着手・設計もまだ）

ユーザーがGoogle Driveにチェックポイントをアップロードし、その旨を
伝えてきたら:

1. 既に接続済みのGoogle Driveコネクタ（`mcp__Google_Drive__*`ツール群）
   経由でファイルを取得する。
2. `CFRSolver.load()`で正常に読み込めるか、情報集合数が期待通りか
   （目標到達なら9,220万件前後、RSS上限で早期停止していればそれより
   少ない数——ログの`done:`行に実数が出ているはずなので、それと
   照合する。**捏造・推測で数字を埋めない**）を確認する。
3. **この時点でのチェックポイントを、アプリが使う
   `assets/solved_spots/solved_spots.json`形式にどう変換するかは、
   まだ設計していない。** 既存の`solver/export_solved_spots.py`は、
   個別の狭いスポット（例: AA vs KK、QQ+ vs TT-JJのような特定の
   ハンド対ハンドの局面）を対象にしたエクスポートで、全169ハンド
   レンジ（ヒーローが169通りのどのハンドを持っていてもよい前提の
   学習結果）をどうエクスポートするかは別の設計が必要
   （タスクリストの保留項目「ソルバー Stage 9: 新スポットの学習・
   検証・エクスポート（全ハンド対応含む）」に対応する）。
   実データ（実際のチェックポイントの中身）を見てから、捏造せずに
   設計すること。
4. 統合後は`flutter analyze` / `flutter test`で回帰確認、
   feature branch → PR → CI green → マージという通常の流れに従う。

## 6. その他、未着手のタスク（今回のスコープ外・優先度は低いが記録として残す）

タスクリストより、pending/未着手のもの:

- **タスク#35（pending）**: ソルバー Stage 9: 新スポットの学習・検証・
  エクスポート（全ハンド対応含む）——上記5節がこれに対応する。
- `AGENTS.md`記載の未着手項目（README.mdの「今後追加したい機能」も参照）:
  - 用語テストの誤答率が高いカテゴリの拡充
  - トレーナーシナリオを11〜15本目まで追加
  - トレーナーの結果を学習履歴に記録する導線
  - **レンジデータの検証**（BTNオープンVPIPが52.2%で一般的な40〜48%
    より広い疑い——最優先の商用リスクとしてAGENTS.mdに明記されている）
  - 匿名ログインで`range_actions`を誰でも全件読めるRLS設計の見直し
  - 活動のない匿名ユーザーの定期削除
  - 1日3問の無料枠が未実装
- README.mdの「今後追加したい機能」: AI自動クイズ生成、Spaced
  Repetition、Tournament ICM、Hand Historyインポート、
  スクリーンショット読み取り、Weekly Report、Achievement、Coach Chatなど
  （いずれも設計未着手）。

これらはユーザーから明示的な優先指示（「ソルバーが最優先だ」等）が
出るまで着手しない——このセッションでの優先順位付けの実績に倣うこと。

## 7. 主要ファイルの場所

- `solver/cfr_solver/cfr.py` — CFR/CFR+トレーナー本体（`save()`/`load()`含む）
- `solver/cfr_solver/games/postflop_subgame.py` — フロップ以降のゲーム定義
- `solver/native/src/` — Rust実装（`node_index.rs`, `equity_cache.rs`,
  `cards.rs`, `history.rs`, `rules.rs`, `strategy.rs`, `walk.rs`）
- `solver/export_solved_spots.py` — 個別スポットの学習・エクスポート
  （全169ハンド版はまだ無い）
- `solver/train_full169.py` — 今回追加した、外部マシン向け全169ハンド
  学習スクリプト
- `solver/BENCHMARKS.md` — 全実測記録（最重要の一次資料）
- `assets/solved_spots/solved_spots.json` — アプリが読み込む解決済み
  スポットのデータ（現状は狭いスポットのみ）
- `lib/features/hand_review/` 他 — `solved_spots.json`を消費するUI側

## 8. 主要URL

- **GitHubリポジトリ（push先）**: https://github.com/momozow1979-stack/poker-coach
- **フロントエンド公開プレビュー**（`main`マージ時にGitHub Actionsで自動公開、
  誰でも閲覧可能）: https://momozow1979-stack.github.io/poker-coach/
- **Supabase管理画面**（プロジェクトダッシュボード。Authentication →
  URL Configuration・Providers等はここから）:
  https://supabase.com/dashboard/project/rfxcovghfifmagnbjayl
- **Google Cloud Console**: このセッションの記録には具体的なプロジェクトURLが
  残っていない。ユーザーに確認するか、Google Cloud Consoleのプロジェクト
  選択画面から該当プロジェクトを開くこと。**推測でURLを作らない。**

## 9. ハンド検証後にやる予定だった改修内容（クラウド側チャットより2026-09-10追記）

2026-09-05時点でもも さんが指示した実行順序は:
1. ソルバー完成（Rust書き換え → Stage 9で新スポット追加）
2. **今のアプリに反映**（ハンドの検証が終わったらやる予定だった本体、以下パート2・3）
3. その後、ゲーム要素追加

### パート2: 新スポットの学習・検証・エクスポート・アプリ反映

Rust化で確保した計算予算内で、板の質感が異なる新スポット（ペアボード、
ツートーン/モノトーンボード、connectedボード、全169ハンド対応含む）を
学習・検証し、`solved_spots.json`を再生成。Flutter側の`hand_review`等に
反映し、`flutter test`で回帰確認。（タスク#35「ソルバー Stage 9」に対応、
本引き継ぎ書5節も参照）

### パート3: AI相手にリアルタイム練習＋リプレイ解説機能

**なぜ**: 既存のハンドトレーナー（固定分岐の多肢選択、乱数もAIも無い）が
「覚えるのがつまらない」という要望に対し、本物のカード配布・コンピュータ
相手・ベット額選択・リプレイ解説を追加する。

**新規モジュール**: `lib/features/practice_table/`（既存`hand_trainer`とは
別）。`hand_review`/`range_chart`の既存ドメインロジックを再利用。

**設計要点**:
- 同じイベントログがライブ/リプレイ両方を駆動
- 相手AIはハイブリッド: 解けている局面はソルバー実測データ（「実測値」と
  明記）、それ以外は簡易ロジック（「目安」と明記）——捏造防止規律を継続
- ベット額はプリセット（33%/66%/100%/オールイン）
- 既存の`PokerTableView`等のアニメーションは無改修で流用

**実装段階**:
1. ドメイン骨格
2. ストリート進行エンジン
3. レンジ考慮配布
4. 簡易AI
5. ソルバー裏付けハイブリッド
6. ライブ対戦画面
7. リプレイ画面
8. 解説パネル + 捏造防止テスト拡張
9. 仕上げ
10. 保留（履歴保存・自由入力ベット額）

**要ユーザー判断**:
- 導線の場所（既定案/quiz/practiceのどこに置くか）
- ヴィランの手札を隠すか（既定=隠す）
- 相手プロファイルを選択可能にするか
- 「考え中」演出・履歴保存の有無

**対象ファイル**: `lib/features/practice_table/`（新規一式）、
`lib/features/hand_review/domain/`（参照/一部関数切り出し）、
`lib/app/router.dart`（新規ルート）

## 10. 全タスク履歴（旧セッションのタスク管理ツールの中身、全件）

```
#1. [completed] solver/ パッケージの雛形作成（pyproject.toml, ディレクトリ構成, .gitignore）
#2. [completed] 抽象ゲームインターフェース game.py + 汎用整合性テスト
#3. [completed] CFR+ トレーナー実装（N人対応）
#4. [completed] Exploitability / best-response 計算実装（N人対応）
#5. [completed] Kuhn Poker 実装 + 収束テスト
#6. [completed] Leduc Hold'em 実装 + 収束テスト
#7. [completed] 3人版 Kuhn Poker 実装 + N人拡張の検証テスト
#8. [completed] CI に solver-tests ジョブを追加
#9. [completed] feature ブランチにコミットして draft PR 作成
#10. [completed] 52枚デッキ + 5枚役評価器を実装
#11. [completed] RangeNotation パーサーを Python に移植
#12. [completed] レンジ→具体コンボ展開 + ボード実測でコンボ数を確認
#13. [completed] ヘッズアップ・フロップサブゲームのGame実装
#14. [completed] 性能ゲート: 学習時間とexploitabilityを実測して次を判断
#15. [completed] テスト作成・コミット・PR作成
#16. [completed] TexasSolverをクローン・ビルド
#17. [completed] 同一条件の局面をTexasSolverで解く
#18. [completed] 自前CFRエンジンの結果と数値を照合
#19. [completed] マルチストリート版のGameを設計・実装
#20. [completed] 極小レンジで整合性・木のサイズを確認
#21. [completed] 学習・収束を実測し性能ゲートを更新
#22. [completed] テスト作成・コミット・PR作成
#23. [completed] External Sampling MCCFR を cfr.py に実装
#24. [completed] Kuhn Pokerで回帰確認
#25. [completed] PostflopSubgameで実際に効果があるか実測
#26. [completed] テスト作成・BENCHMARKS更新・コミット・PR
#27. [completed] 実ソルバー結果をJSONでエクスポート
#28. [completed] SolvedSpotデータモデル+リポジトリをFlutter側に実装
#29. [completed] hand_reviewのgtoViewに実データを配線
#30. [completed] UIデザイン方向性を決めて配色・タイポグラフィを刷新
#31. [completed] アプリアイコン・ちょっとした演出要素を追加
#32. [completed] ソルバー Stage 6: ホットパス最適化(simulate_round/key/dispatch)
#33. [completed] ソルバー Stage 7: コンボペア単位の並列化
#34. [completed] ソルバー Stage 8: 判断ゲート(Rust書き換えの要否を実測で判断)
#35. [pending] ソルバー Stage 9: 新スポットの学習・検証・エクスポート（全ハンド対応含む）
#36. [completed] UI-A: トレーナー機能の名称統一・タブ移動
#37. [completed] UI-B: ホームタブ再設計(振り返りカード・苦手分野の直接リンク)
#38. [completed] UI-C: アクションの視覚化(色/アイコン/頻度バー/簡易アニメーション)
#39. [completed] UI-D: 初回オンボーディングフロー
#40. [completed] UI-E: レンジ表MIX色分け + vsOpenシナリオ追加
#41. [completed] レンジ表詳細シートにActionFrequencyBarを配線
#42. [completed] クイズのアクション種別タグ付けを残り9カテゴリへ拡大
#43. [completed] クイズ解説にrelatedRangeSpotId経由の実頻度データを配線
#44. [completed] vsOpenレンジ表データをTexasSolverで検証
#45. [completed] マージ済みUI変更のヘッドレスブラウザ目視確認
#46. [completed] Rust化 Stage 8R-1: PyO3クレート雛形+maturin+CI配線
#47. [completed] Rust化 Stage 8R-2: 役評価器の移植+全数検証
#48. [completed] Rust化 Stage 8R-3: PostflopSubgameルール移植
#49. [completed] Rust化 Stage 8R-4: 単一スレッド探索木+公開API
#50. [completed] Rust化 Stage 8R-5: Rayon並列化
#51. [completed] Rust化 Stage 8R-6: 実スポットのCIフィクスチャ化
#52. [completed] Rust化 Stage 8R-7: 実レンジ幅ベンチマーク
#53. [completed] Rust化 Stage 8R-8: export_solved_spots.py統合
#54. [completed] 全ハンド対応 Stage S1: CFR保存層のRust化設計・実測
#55. [completed] 全ハンド対応 Stage S2: 全169ハンド規模での実測
#56. [completed] CFRSolverの学習状態を保存・再開できるようにする
#57. [completed] CFRSolver.save()のピークRSS膨張バグを修正
#58. [completed] cgroupメモリ上限(13.34GiB)発覚への対応と再開
```

このセッションではさらに以下が完了している（旧タスク管理ツールには
未登録だが、実際にmainへマージ済みの作業。3節参照）:

- PR #28: Google Sign-In実装
- PR #29: Rustソルバー書き換え一式をmainへ統合
- PR #30: `export_solved_spots.py`のexploitabilityをRustで実計算するように変更
- PR #31: `_equity_cache`のRust化（EquityCache、5.3倍圧縮）
- PR #32: `CFRSolver.save()`のアトミック書き込み化
- PR #33: `save()`の`.tobytes()`コピー除去
- PR #34: `solver/train_full169.py`追加（全169ハンド対応学習の外部実行スクリプト）

## 11. このセッション固有の連絡先情報

- ユーザーのメール: momo.yoko@bywill.co.jp（本人特定用途のみ、外部送信禁止）
- 旧セッションURL（参考情報。新セッションは自分自身のセッションURLを
  コミット/PRに使うこと）:
  https://claude.ai/code/session_01WynDSW8mfeh7yHM7xw5YPr
