# AGENTS.md — このリポジトリで作業する AI エージェント向けの引き継ぎメモ

このファイルは Codex / Claude Code など、どの AI コーディングエージェントが
このリポジトリを触るときにも最初に読む前提で書いている。
プロジェクトの背景や現状は `README.md` と `docs/ai-prompts.md` を参照。
ここには **README に書かれていない、実装時に踏んだ地雷とルール** だけをまとめる。

## 絶対に守ること（原則）

1. **AI に GTO の頻度や EV の数値を捏造させない。**
   数値を出してよいのは、計算で導出できるとき（ポットオッズ、必要勝率、SPR、アウツ）だけ。
   ソルバー結果が入力に無いのに「GTOでは35%の頻度で」のような数字を書かせない。
2. **OpenAI の API キーをアプリに埋め込まない。**
   呼び出しは必ずサーバー側（Supabase Edge Function）から行う。クライアントコードに置かない。
3. **`sb_secret_` で始まる Supabase の鍵は絶対に使わない。**
   コード・設定ファイル・コミット・ログのどこにも書かない。
   `sb_publishable_` は公開されて問題ない鍵なので OK（`lib/core/config/app_config.dart` 参照）。
4. 解説文は初心者が読んで分かる日本語で書く。「GTOだから」で終わらせない。
5. 「唯一の正解」を断定しすぎない。
   **なぜその選択が良いのか / 何が変われば別の選択が良くなるか** を必ず書く
   （`TrainerOption` が `reason` と `ifChanged` の両方を型で強制しているのはこのため）。

## ユーザー（もも さん）とのやり取りに関するルール

- **ユーザーへの説明・コミュニケーションは日本語で行う。** UI も日本語が前提。
- 初心者でも迷わないこと、見やすいことを最優先にする。
- 破壊的な操作（force push、DB の直接操作、履歴の書き換えなど）は必ず先に確認する。

## 検証ルール

- コミット・PR 前に `flutter analyze` がクリーンであること、`flutter test` が全部通ること。
- **UI を変更したら、必ずブラウザで実際に見て確認すること。** テストが通るだけでは不十分
  （このセッションだけでもテストでは検出できない表示崩れを 5 件以上、目視で発見している）。
  ```
  flutter build web --release --no-web-resources-cdn --pwa-strategy=none
  # 出力を任意の HTTP サーバーで配信し、Playwright 等でスクリーンショットを撮る
  ```
- 作業は feature ブランチ → draft PR で行う。`main` を直接壊さない。

## 踏んだ地雷（同じ轍を踏まないために）

- **オープンレンジ（RFI）はソルバー系の公開資料に合わせてある。** 6MAX・100BB で
  UTG 13.5% / HJ 19.1% / CO 27.9% / BTN 42.8% / SB 39.5%（mixed は 0.5 として数える）。
  参照値は GTO Wizard（BTN 約42%）・Upswing（UTG 約16%・CO 24.9%・BTN 40.9%）。
  一度「初心者向けに絞る」として全席を 3〜9 ポイント狭めたが、解説が「ソルバーでも外れる」と
  断定していたため事実と食い違い、元に戻した。レンジを変えるときは割合を計算して参照値と比べ、
  解説文（`range_guidance.dart`）で「ソルバーでも〜」と断定しないこと。
  9MAX の席別の信頼できる参照値は見つかっていない（未検証）。

- **Flutter Web のビルドには `--no-web-resources-cdn --pwa-strategy=none` が必須。**
  無いとビルド時に外部 CDN を叩きに行って失敗することがある。
- **CustomPainter 内の TextPainter は `DefaultTextStyle` を継承しない。**
  素の `TextStyle` を渡すと日本語フォントが当たらず文字化けする。
  必ず `lib/core/theme/canvas_text.dart` の `canvasTextStyle()` を使う。
  **このバグはこのセッション内だけで3回再発した。** CustomPainter を新規に書くときは要注意。
- `ThemeData` のコンポーネントテーマは、必ず `textTheme` から派生させる。素の `TextStyle` を直書きしない。
- `Container` + `alignment` は幅いっぱいに広がる。中央寄せしたいだけなら `Center(widthFactor: 1)` を使う。
- Riverpod 3 では `AsyncValue.valueOrNull` は存在しない。`AsyncValue.value` を使う。
- ウィジェットテストで `scrollUntilVisible` は `.first` を含む finder だと失敗することがある。
  `find.byType(Scrollable).first` を手動でループしてドラッグする。
- **Flutter Web はそのままでは要素のテキストを DOM に出さない。**
  `document.querySelector('flt-semantics-placeholder').click()` でセマンティクスを有効にすると、
  `flt-semantics[role="button"]` にボタンの文言が入る。Playwright ではその要素の
  `getBoundingClientRect()` の中心を `page.mouse.click` で押せば、文言を手がかりに操作できる。
- 練習テーブル（AI 対戦）の採点は `lib/features/practice_table/domain/grading/`。
  選んだ理由（バリュー・ブラフ・ポットオッズなど）の判定は同じフォルダの `decision_reason.dart`。
  理由は「計算した数字で真偽が決まる文」だけにすること（数字で確かめられない理由を足さない）。
  相手 AI の打ち方を変えたら、採点も同じ打ち方で計算されるので、
  `decision_grader_test.dart` の前提（どの手でベット・降りるか）を見直すこと。
  相手には型（`PracticeOpponentStyle`: ふつう・ブラフ多め・バリュー多め・受けすぎ）があり、
  ハンドの記録に型が残る。振り返りの採点はその型で計算するので、型の打ち方を変えると
  過去の記録の採点も変わる。「育つ相手」は採点で × が多い判断の種類を突く型を選ぶ
  （回数ではなく × で見る。相手によっては多く降りるのが正解のため）。
- Playwright で端末保存のデータを仕込むときは、`SharedPreferencesAsync` は
  localStorage に **`flutter.` を付けないキー**（例: `practice_table.logs.v1`）で保存する。
  文字列リストは JSON 配列の文字列にする。
- **日本語フォントは Google Fonts のランタイム取得に頼らない。**
  このネットワーク環境ではブラウザから fonts.gstatic.com に到達できず、文字が豆腐（□）になる。
  Noto Sans JP を `assets/fonts/` に同梱済み（Regular 400 + Bold 700）。新しいフォントを足すときも同梱すること。
- **ポジションの前後判定（IP/OOP）にプリフロップの着手順（`Position.orderFor`）を使わない。**
  フロップ以降は SB から始まる別の順序になる。`Position.postflopOrderFor` /
  `Position.isInPositionAgainst` を使うこと。一度これを取り違えて
  「BTN vs BB」が逆に表示されるバグを出した。
- 金額（BB）が不明なときは、null のまま扱って「ポットオッズの話ではありません」のように
  分岐する。**0 や仮の数値で埋めない。** `HandFlow` / `ActionPrompt.requiredEquity` の設計を参照。

## 現在の状態

- `main` は PR #2（ハンド入力の自動進行・レビュー内容の作り直し）までマージ済み。
- 未着手・提案中の項目:
  - 用語テストの誤答率が高いカテゴリの拡充
  - トレーナーシナリオを 11〜15 本目まで追加
  - トレーナーの結果を学習履歴に記録する導線
  - 匿名ログインで `range_actions` を誰でも全件読める（RLS が `to authenticated using (true)`）。
    買い切り課金の構想と噛み合わないので要設計
  - 活動のない匿名ユーザーの定期削除（Supabase は MAU 課金のため）
  - 1日3問の無料枠が未実装
  - Google 認証の追加（メール認証・匿名ファーストは実装済み。
    `linkIdentityWithIdToken` で匿名アカウントに紐付ける設計。
    Google Cloud Console / Supabase ダッシュボードの設定はユーザー側の作業）
