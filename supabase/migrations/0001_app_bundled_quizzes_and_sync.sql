-- 0001: アプリ同梱クイズの記録と、オフライン同期の冪等化
--
-- 適用先: 既に schema.sql を流してある Supabase プロジェクト。
-- Supabase ダッシュボード → SQL Editor に貼って実行する。
-- 何度実行しても同じ結果になる（冪等）。
--
-- 背景:
--  1. クイズ 300 問はアプリに同梱したままにするため、`quizzes` テーブルには行が無い。
--     `quiz_attempts.quiz_id` は `quizzes` への NOT NULL 外部キーなので、そのままでは
--     1 件も記録できない。アプリ内の問題 ID（'preflop-001' など）を入れる
--     `quiz_key` を足し、`quiz_id` を NULL 許容にする。
--  2. 圏外で溜めた回答を復帰時に再送するとき、送信結果が分からないまま再送しても
--     行が重複しないように、端末側で採番した `client_id` に一意制約を張る。

-- 1. アプリ同梱クイズを記録できるようにする ---------------------------------
alter table public.quiz_attempts
  add column if not exists quiz_key  text,
  add column if not exists category  text,
  add column if not exists client_id text;

alter table public.quiz_attempts
  alter column quiz_id drop not null;

-- quiz_id（DB のクイズ）か quiz_key（アプリ同梱のクイズ）のどちらかは必ず入る。
alter table public.quiz_attempts
  drop constraint if exists quiz_attempts_quiz_reference_check;
alter table public.quiz_attempts
  add constraint quiz_attempts_quiz_reference_check
  check (quiz_id is not null or quiz_key is not null);

-- 2. 再送しても重複しないようにする -----------------------------------------
create unique index if not exists quiz_attempts_user_client_id_idx
  on public.quiz_attempts (user_id, client_id);

alter table public.hand_reviews
  add column if not exists client_id text;

create unique index if not exists hand_reviews_user_client_id_idx
  on public.hand_reviews (user_id, client_id);

-- 3. カテゴリ別集計の取得を速くする -----------------------------------------
create index if not exists quiz_attempts_user_category_idx
  on public.quiz_attempts (user_id, category);
