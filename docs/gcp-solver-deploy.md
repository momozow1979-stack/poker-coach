# ソルバーを GCP（Cloud Run Jobs）で回す手順

ローカル PC の代わりに、CFR ソルバーをクラウドのバッチとして実行し、結果 JSON を
Cloud Storage に出す。アプリはその JSON を（同梱 or 取得で）使う。

前提: GCP プロジェクトと課金が有効で、`gcloud` CLI で認証済み
（`docs` 冒頭の Step 1〜7 相当）。以下の `PROJECT_ID` と `BUCKET` は自分の値に置換。

```bash
# 変数（自分の値に）
PROJECT_ID=あなたのプロジェクトID
BUCKET=poker-coach-solver-〇〇
REGION=asia-northeast1
IMAGE=$REGION-docker.pkg.dev/$PROJECT_ID/poker-coach/solver:latest
```

## 1. イメージをビルド（Cloud Build → Artifact Registry）
`solver/` ディレクトリを丸ごとビルドする（Dockerfile 同梱）。

```bash
gcloud builds submit solver --tag "$IMAGE"
```

## 2. ジョブのサービスアカウントに、バケットへの書き込み権限を付与
```bash
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" \
  --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role=roles/storage.objectAdmin
```

## 3. Cloud Run Job を作成
CPU 8・メモリ 32Gi・タイムアウト最大（24h）。出力先は環境変数で渡す。

```bash
gcloud run jobs create solver-srp \
  --image "$IMAGE" \
  --region "$REGION" \
  --cpu 8 --memory 32Gi \
  --max-retries 0 --task-timeout 86400 \
  --set-env-vars "OUTPUT_GCS_URI=gs://$BUCKET/solved_srp_btn_bb.json"
```

## 4. 実行
```bash
gcloud run jobs execute solver-srp --region "$REGION"
```
進行はコンソールの Cloud Run > ジョブ、または:
```bash
gcloud run jobs executions list --job solver-srp --region "$REGION"
```

## 5. 結果をアプリに取り込む
学習が終わると `gs://$BUCKET/solved_srp_btn_bb.json` に出力される。アプリの
アセットへコピーして通常どおりコミット（当面は同梱方式）:

```bash
gcloud storage cp "gs://$BUCKET/solved_srp_btn_bb.json" \
  poker-coach/assets/gto/solved_srp_btn_bb.json
```

> 将来、アプリから GCS の URL を直接取得する方式に切り替える場合は、
> `lib/features/gto_strategy/application/gto_flop_providers.dart` の読み込み元を
> `rootBundle`（同梱）から HTTP 取得（GCS 公開 URL / CDN）に変えるだけでよい。

## 盤やマッチアップを増やすには
`solver/solve_srp_btn_bb.py` の `BOARDS`（や `BTN_OPEN`/`BB_CALL`）を編集して 1〜2 を
繰り返す。クラウドなら複数ジョブを並列に投げられる（`--tasks` 配列 + ボード index 分割）。
反復数 `ITERATIONS` を上げると精度が上がる（そのぶん時間・費用が増える）。

## コスト目安
1 盤 12M 反復で数時間。スポット/従量で 1 回あたり数百円程度。ユーザー数とは無関係
（全員が同じ計算済み JSON を読むだけ）。
