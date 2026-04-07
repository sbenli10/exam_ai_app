-- AI ile üretilen soruların öğretmen onay süreci için gerekli alanlar.

alter table public.questions
  add column if not exists source text default 'manual';

alter table public.questions
  add column if not exists generation_job_id uuid
  references public.question_generation_jobs(id);

alter table public.questions
  add column if not exists measurement_focus text;

alter table public.questions
  add column if not exists is_verified boolean not null default false;

alter table public.questions
  add column if not exists verified_by uuid
  references auth.users(id);

alter table public.questions
  add column if not exists verified_at timestamp with time zone;

create index if not exists idx_questions_is_verified
on public.questions (is_verified, exam_id, subject_id, topic_id);

create index if not exists idx_questions_generation_job_id
on public.questions (generation_job_id);
