alter table public.profiles
add column if not exists nickname text;

update public.profiles
set nickname = split_part(email, '@', 1)
where coalesce(trim(nickname), '') = '';

alter table public.profiles
alter column nickname set not null;

