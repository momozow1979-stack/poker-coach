-- AI Poker Coach - Supabase スキーマ
--
-- 仕様書 8. Supabase DB設計 を SQL にしたもの。新規プロジェクトはこれを流せば揃う。
-- 既に旧版を適用済みのプロジェクトには migrations/0001_*.sql を追加で流す。

create extension if not exists "pgcrypto";

-- プロフィール --------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'プレイヤー',
  poker_level text not null default 'novice'
    check (poker_level in ('beginner', 'novice', 'intermediate', 'advanced')),
  created_at timestamptz not null default now()
);

-- クイズ --------------------------------------------------------------------
create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  difficulty int not null default 1,
  question_json jsonb not null,
  correct_answer_json jsonb not null,
  explanation_json jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists quizzes_category_idx
  on public.quizzes (category) where active;

-- クイズ 300 問はアプリに同梱している。そのため `quiz_id`（quizzes への参照）は
-- NULL 許容にし、アプリ内の問題 ID を `quiz_key` に入れる。
-- `client_id` は端末側で採番する同期キー。圏外ぶんを再送しても重複しない。
create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  quiz_id uuid references public.quizzes (id) on delete cascade,
  quiz_key text,
  category text,
  client_id text,
  selected_answer_json jsonb not null,
  is_correct boolean not null,
  answered_at timestamptz not null default now(),
  constraint quiz_attempts_quiz_reference_check
    check (quiz_id is not null or quiz_key is not null)
);

create index if not exists quiz_attempts_user_answered_idx
  on public.quiz_attempts (user_id, answered_at desc);

create index if not exists quiz_attempts_user_category_idx
  on public.quiz_attempts (user_id, category);

create unique index if not exists quiz_attempts_user_client_id_idx
  on public.quiz_attempts (user_id, client_id);

-- レンジ表 ------------------------------------------------------------------
create table if not exists public.range_spots (
  id uuid primary key default gen_random_uuid(),
  table_type text not null check (table_type in ('6max', '9max')),
  situation text not null
    check (situation in ('open_raise', 'vs_open', 'vs_3bet', 'vs_4bet')),
  hero_position text not null,
  villain_position text,
  stack_bb numeric not null default 100,
  title text not null
);

create table if not exists public.range_actions (
  id uuid primary key default gen_random_uuid(),
  range_spot_id uuid not null
    references public.range_spots (id) on delete cascade,
  hand text not null,
  action text not null
    check (action in ('raise', 'call', 'fold', '3bet', '4bet', 'mixed')),
  frequency numeric not null default 1,
  explanation text,
  unique (range_spot_id, hand)
);

-- ハンドレビュー ------------------------------------------------------------
create table if not exists public.hand_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text,
  input_json jsonb not null,
  ai_response_json jsonb not null,
  score int not null,
  created_at timestamptz not null default now()
);

create index if not exists hand_reviews_user_created_idx
  on public.hand_reviews (user_id, created_at desc);

create unique index if not exists hand_reviews_user_client_id_idx
  on public.hand_reviews (user_id, client_id);

-- AI コーチ -----------------------------------------------------------------
create table if not exists public.coach_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  message text not null,
  message_type text not null
    check (message_type in ('daily', 'focus', 'growth', 'improvement', 'tomorrow')),
  created_at timestamptz not null default now()
);

-- 学習統計 ------------------------------------------------------------------
create table if not exists public.learning_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null,
  correct_count int not null default 0,
  incorrect_count int not null default 0,
  last_updated timestamptz not null default now(),
  unique (user_id, category)
);

-- Row Level Security --------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.hand_reviews enable row level security;
alter table public.coach_messages enable row level security;
alter table public.learning_stats enable row level security;

-- 自分のデータだけ読み書きできる。
create policy "own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own attempts" on public.quiz_attempts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own reviews" on public.hand_reviews
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own coach messages" on public.coach_messages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own learning stats" on public.learning_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- クイズとレンジ表はログインユーザー全員が読める。
alter table public.quizzes enable row level security;
alter table public.range_spots enable row level security;
alter table public.range_actions enable row level security;

create policy "read quizzes" on public.quizzes
  for select to authenticated using (active);
create policy "read range spots" on public.range_spots
  for select to authenticated using (true);
create policy "read range actions" on public.range_actions
  for select to authenticated using (true);
