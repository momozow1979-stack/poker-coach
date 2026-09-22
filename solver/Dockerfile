# CFR ソルバーを GCP の Cloud Run Jobs（バッチ）で回すための Linux イメージ。
#
# ネイティブ拡張（cfr_solver._native）は Rust/PyO3 を maturin でビルドする。
# Windows でコミット済みの .pyd は Linux では使えないため、ここで作り直す。
FROM python:3.12-slim

# Rust ツールチェーンとビルド道具（maturin のネイティブビルドに必要）。
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app
COPY . /app

# maturin build-backend が native/ をコンパイルし、cfr_solver._native を入れる。
# google-cloud-storage は結果を GCS にアップするために追加。
RUN pip install --no-cache-dir . google-cloud-storage

# 既定は BTN vs BB SRP の学習。実行時に環境変数で上書き可能:
#   OUTPUT_GCS_URI=gs://bucket/solved_srp_btn_bb.json を渡すと結果をアップロードする。
CMD ["python", "-u", "solve_srp_btn_bb.py"]
