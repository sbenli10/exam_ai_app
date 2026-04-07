create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.get_period_start(
  period_type text,
  reference_at timestamp with time zone
)
returns date
language plpgsql
immutable
as $$
begin
  if period_type = 'weekly' then
    return date_trunc('week', reference_at)::date;
  elsif period_type = 'monthly' then
    return date_trunc('month', reference_at)::date;
  elsif period_type = 'all_time' then
    return date '1970-01-01';
  end if;

  raise exception 'Unsupported period_type: %', period_type;
end;
$$;

create or replace function public.get_period_end(
  period_type text,
  reference_at timestamp with time zone
)
returns date
language plpgsql
immutable
as $$
begin
  if period_type = 'weekly' then
    return (date_trunc('week', reference_at) + interval '6 day')::date;
  elsif period_type = 'monthly' then
    return (date_trunc('month', reference_at) + interval '1 month - 1 day')::date;
  elsif period_type = 'all_time' then
    return date '2099-12-31';
  end if;

  raise exception 'Unsupported period_type: %', period_type;
end;
$$;

create or replace function public.get_wrong_penalty_divisor(exam_name text)
returns numeric
language plpgsql
immutable
as $$
begin
  case upper(exam_name)
    when 'YKS' then return 4.0;
    when 'LGS' then return 4.0;
    when 'KPSS' then return 4.0;
    when 'ALES' then return 4.0;
    else return 4.0;
  end case;
end;
$$;

create table if not exists public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  option_key text not null check (option_key in ('A', 'B', 'C', 'D', 'E')),
  option_text text not null,
  created_at timestamp with time zone not null default now(),
  unique (question_id, option_key)
);

create index if not exists question_options_question_id_idx
  on public.question_options (question_id);

insert into public.question_options (question_id, option_key, option_text)
select q.id, option_data.option_key, option_data.option_text
from public.questions q
cross join lateral (
  values
    ('A', q.option_a),
    ('B', q.option_b),
    ('C', q.option_c),
    ('D', q.option_d),
    ('E', q.option_e)
) as option_data(option_key, option_text)
where option_data.option_text is not null
on conflict (question_id, option_key) do nothing;

create table if not exists public.question_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  exam_id uuid not null references public.exams (id) on delete cascade,
  subject_id uuid references public.subjects (id) on delete set null,
  topic_id uuid references public.topics (id) on delete set null,
  selected_answer text check (selected_answer in ('A', 'B', 'C', 'D', 'E')),
  is_correct boolean not null,
  is_blank boolean not null default false,
  used_ai_help boolean not null default false,
  time_spent_seconds int not null default 0 check (time_spent_seconds >= 0),
  points_awarded int not null default 0,
  net_delta numeric(8,2) not null default 0,
  attempt_no int not null default 1,
  created_at timestamp with time zone not null default now(),
  unique (user_id, question_id, attempt_no)
);

create index if not exists question_attempts_user_exam_created_idx
  on public.question_attempts (user_id, exam_id, created_at desc);

create index if not exists question_attempts_question_idx
  on public.question_attempts (question_id);

create table if not exists public.mock_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  exam_id uuid not null references public.exams (id) on delete cascade,
  subject_id uuid references public.subjects (id) on delete set null,
  topic_id uuid references public.topics (id) on delete set null,
  mock_type text not null check (mock_type in ('mini', 'branch', 'full')),
  title text not null,
  question_count int not null check (question_count > 0),
  correct_count int not null default 0 check (correct_count >= 0),
  wrong_count int not null default 0 check (wrong_count >= 0),
  blank_count int not null default 0 check (blank_count >= 0),
  net_score numeric(8,2) not null default 0,
  points_awarded int not null default 0,
  duration_seconds int not null default 0 check (duration_seconds >= 0),
  started_at timestamp with time zone not null default now(),
  completed_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  check (correct_count + wrong_count + blank_count <= question_count)
);

create index if not exists mock_attempts_user_exam_completed_idx
  on public.mock_attempts (user_id, exam_id, completed_at desc);

create table if not exists public.leaderboard_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  exam_id uuid not null references public.exams (id) on delete cascade,
  period_type text not null check (period_type in ('weekly', 'monthly', 'all_time')),
  period_start date not null,
  period_end date not null,
  total_points int not null default 0,
  total_net numeric(10,2) not null default 0,
  solved_questions_count int not null default 0,
  correct_count int not null default 0,
  wrong_count int not null default 0,
  blank_count int not null default 0,
  mock_count int not null default 0,
  rank_position int,
  updated_at timestamp with time zone not null default now(),
  unique (user_id, exam_id, period_type, period_start)
);

create index if not exists leaderboard_stats_exam_period_rank_idx
  on public.leaderboard_stats (exam_id, period_type, period_start, total_points desc, total_net desc);

create trigger set_leaderboard_stats_updated_at
before update on public.leaderboard_stats
for each row execute function public.set_updated_at();

create or replace function public.apply_question_attempt_scoring()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  question_record public.questions%rowtype;
  exam_name text;
  penalty_divisor numeric;
begin
  select *
  into question_record
  from public.questions
  where id = new.question_id;

  if question_record.id is null then
    raise exception 'Question not found for attempt: %', new.question_id;
  end if;

  new.exam_id := question_record.exam_id;
  new.subject_id := question_record.subject_id;
  new.topic_id := question_record.topic_id;

  select name
  into exam_name
  from public.exams
  where id = new.exam_id;

  penalty_divisor := public.get_wrong_penalty_divisor(exam_name);

  if new.is_blank then
    new.points_awarded := 0;
    new.net_delta := 0;
  elsif new.is_correct then
    new.points_awarded := case
      when new.used_ai_help then 6
      else 10
    end;
    new.net_delta := 1.00;
  else
    new.points_awarded := 0;
    new.net_delta := round((-1.00 / penalty_divisor)::numeric, 2);
  end if;

  return new;
end;
$$;

create or replace function public.apply_mock_attempt_scoring()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  exam_name text;
  penalty_divisor numeric;
  base_points int;
begin
  select name
  into exam_name
  from public.exams
  where id = new.exam_id;

  penalty_divisor := public.get_wrong_penalty_divisor(exam_name);

  new.net_score := round(
    (new.correct_count - (new.wrong_count::numeric / penalty_divisor))::numeric,
    2
  );

  base_points := new.correct_count * 10;

  if new.mock_type = 'mini' then
    new.points_awarded := base_points + 20;
  elsif new.mock_type = 'branch' then
    new.points_awarded := base_points + 40;
  else
    new.points_awarded := base_points + 75;
  end if;

  return new;
end;
$$;

drop trigger if exists question_attempts_apply_scoring on public.question_attempts;

create trigger question_attempts_apply_scoring
before insert or update on public.question_attempts
for each row execute function public.apply_question_attempt_scoring();

drop trigger if exists mock_attempts_apply_scoring on public.mock_attempts;

create trigger mock_attempts_apply_scoring
before insert or update on public.mock_attempts
for each row execute function public.apply_mock_attempt_scoring();

create or replace function public.refresh_leaderboard_stats_for_user_exam(
  p_user_id uuid,
  p_exam_id uuid,
  p_reference_at timestamp with time zone default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  period_name text;
  current_period_start date;
  current_period_end date;
begin
  foreach period_name in array array['weekly', 'monthly', 'all_time']
  loop
    current_period_start := public.get_period_start(period_name, p_reference_at);
    current_period_end := public.get_period_end(period_name, p_reference_at);

    insert into public.leaderboard_stats (
      user_id,
      exam_id,
      period_type,
      period_start,
      period_end,
      total_points,
      total_net,
      solved_questions_count,
      correct_count,
      wrong_count,
      blank_count,
      mock_count
    )
    select
      p_user_id,
      p_exam_id,
      period_name,
      current_period_start,
      current_period_end,
      coalesce(question_data.total_points, 0) + coalesce(mock_data.total_points, 0),
      coalesce(question_data.total_net, 0) + coalesce(mock_data.total_net, 0),
      coalesce(question_data.solved_questions_count, 0),
      coalesce(question_data.correct_count, 0) + coalesce(mock_data.correct_count, 0),
      coalesce(question_data.wrong_count, 0) + coalesce(mock_data.wrong_count, 0),
      coalesce(question_data.blank_count, 0) + coalesce(mock_data.blank_count, 0),
      coalesce(mock_data.mock_count, 0)
    from (
      select
        sum(points_awarded)::int as total_points,
        round(sum(net_delta)::numeric, 2) as total_net,
        count(*)::int as solved_questions_count,
        count(*) filter (where is_correct)::int as correct_count,
        count(*) filter (where not is_correct and not is_blank)::int as wrong_count,
        count(*) filter (where is_blank)::int as blank_count
      from public.question_attempts
      where user_id = p_user_id
        and exam_id = p_exam_id
        and created_at::date between current_period_start and current_period_end
    ) question_data
    cross join (
      select
        sum(points_awarded)::int as total_points,
        round(sum(net_score)::numeric, 2) as total_net,
        sum(correct_count)::int as correct_count,
        sum(wrong_count)::int as wrong_count,
        sum(blank_count)::int as blank_count,
        count(*)::int as mock_count
      from public.mock_attempts
      where user_id = p_user_id
        and exam_id = p_exam_id
        and completed_at::date between current_period_start and current_period_end
    ) mock_data
    on conflict (user_id, exam_id, period_type, period_start)
    do update set
      period_end = excluded.period_end,
      total_points = excluded.total_points,
      total_net = excluded.total_net,
      solved_questions_count = excluded.solved_questions_count,
      correct_count = excluded.correct_count,
      wrong_count = excluded.wrong_count,
      blank_count = excluded.blank_count,
      mock_count = excluded.mock_count,
      updated_at = now();
  end loop;
end;
$$;

create or replace function public.update_rankings_for_exam_period(
  p_exam_id uuid,
  p_period_type text,
  p_period_start date
)
returns void
language sql
security definer
set search_path = public
as $$
  with ranked as (
    select
      id,
      dense_rank() over (
        order by total_points desc, total_net desc, solved_questions_count desc, updated_at asc
      ) as new_rank
    from public.leaderboard_stats
    where exam_id = p_exam_id
      and period_type = p_period_type
      and period_start = p_period_start
  )
  update public.leaderboard_stats stats
  set rank_position = ranked.new_rank,
      updated_at = now()
  from ranked
  where stats.id = ranked.id;
$$;

create or replace function public.handle_leaderboard_refresh_from_question_attempt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
  target_exam_id uuid;
  weekly_start date;
  monthly_start date;
  all_time_start date;
begin
  target_user_id := coalesce(new.user_id, old.user_id);
  target_exam_id := coalesce(new.exam_id, old.exam_id);

  perform public.refresh_leaderboard_stats_for_user_exam(target_user_id, target_exam_id, now());

  weekly_start := public.get_period_start('weekly', now());
  monthly_start := public.get_period_start('monthly', now());
  all_time_start := public.get_period_start('all_time', now());

  perform public.update_rankings_for_exam_period(target_exam_id, 'weekly', weekly_start);
  perform public.update_rankings_for_exam_period(target_exam_id, 'monthly', monthly_start);
  perform public.update_rankings_for_exam_period(target_exam_id, 'all_time', all_time_start);

  return null;
end;
$$;

create or replace function public.handle_leaderboard_refresh_from_mock_attempt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
  target_exam_id uuid;
  weekly_start date;
  monthly_start date;
  all_time_start date;
begin
  target_user_id := coalesce(new.user_id, old.user_id);
  target_exam_id := coalesce(new.exam_id, old.exam_id);

  perform public.refresh_leaderboard_stats_for_user_exam(target_user_id, target_exam_id, now());

  weekly_start := public.get_period_start('weekly', now());
  monthly_start := public.get_period_start('monthly', now());
  all_time_start := public.get_period_start('all_time', now());

  perform public.update_rankings_for_exam_period(target_exam_id, 'weekly', weekly_start);
  perform public.update_rankings_for_exam_period(target_exam_id, 'monthly', monthly_start);
  perform public.update_rankings_for_exam_period(target_exam_id, 'all_time', all_time_start);

  return null;
end;
$$;

drop trigger if exists question_attempts_refresh_leaderboard on public.question_attempts;

create trigger question_attempts_refresh_leaderboard
after insert or update or delete on public.question_attempts
for each row execute function public.handle_leaderboard_refresh_from_question_attempt();

drop trigger if exists mock_attempts_refresh_leaderboard on public.mock_attempts;

create trigger mock_attempts_refresh_leaderboard
after insert or update or delete on public.mock_attempts
for each row execute function public.handle_leaderboard_refresh_from_mock_attempt();

alter table public.question_options enable row level security;
alter table public.question_attempts enable row level security;
alter table public.mock_attempts enable row level security;
alter table public.leaderboard_stats enable row level security;

create policy "Authenticated users can read question options"
on public.question_options
for select
to authenticated
using (true);

create policy "Authenticated users can insert question options"
on public.question_options
for insert
to authenticated
with check (true);

create policy "Users can read own question attempts"
on public.question_attempts
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own question attempts"
on public.question_attempts
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can read own mock attempts"
on public.mock_attempts
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own mock attempts"
on public.mock_attempts
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Authenticated users can read leaderboard"
on public.leaderboard_stats
for select
to authenticated
using (true);
