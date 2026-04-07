create extension if not exists pgcrypto;

alter table if exists public.questions
  add column if not exists normalized_stem text;

create index if not exists questions_topic_normalized_stem_idx
  on public.questions (topic_id, normalized_stem);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.question_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  topic_id uuid not null references public.topics (id) on delete cascade,
  section_name text,
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  question_style text not null default 'standard' check (
    question_style in (
      'standard',
      'new_generation',
      'short_drill',
      'long_paragraph',
      'table_interpretation',
      'graph_interpretation'
    )
  ),
  target_count int not null check (target_count > 0),
  batch_size int not null default 10 check (batch_size between 1 and 25),
  generated_count int not null default 0 check (generated_count >= 0),
  inserted_count int not null default 0 check (inserted_count >= 0),
  duplicate_count int not null default 0 check (duplicate_count >= 0),
  failed_count int not null default 0 check (failed_count >= 0),
  status text not null default 'pending' check (
    status in ('pending', 'running', 'completed', 'partially_completed', 'failed', 'paused')
  ),
  prompt_version text not null default 'v1',
  notes text,
  last_error text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  started_at timestamp with time zone,
  completed_at timestamp with time zone
);

create index if not exists question_generation_jobs_status_idx
  on public.question_generation_jobs (status, created_at);

create index if not exists question_generation_jobs_topic_idx
  on public.question_generation_jobs (exam_id, subject_id, topic_id);

drop trigger if exists set_question_generation_jobs_updated_at on public.question_generation_jobs;

create trigger set_question_generation_jobs_updated_at
before update on public.question_generation_jobs
for each row execute function public.set_updated_at();

alter table public.question_generation_jobs enable row level security;

create policy "Authenticated users can read generation jobs"
on public.question_generation_jobs
for select
to authenticated
using (true);

create policy "Authenticated users can insert generation jobs"
on public.question_generation_jobs
for insert
to authenticated
with check (true);

create policy "Authenticated users can update generation jobs"
on public.question_generation_jobs
for update
to authenticated
using (true)
with check (true);
