create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    user_id,
    nickname,
    email,
    exam_type,
    target_score
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nickname', split_part(coalesce(new.email, ''), '@', 1), 'ogrenci'),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'exam_type', ''),
    nullif(new.raw_user_meta_data ->> 'target_score', '')::int
  )
  on conflict (user_id) do update
  set
    nickname = excluded.nickname,
    email = excluded.email,
    exam_type = excluded.exam_type,
    target_score = excluded.target_score;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user_profile();

