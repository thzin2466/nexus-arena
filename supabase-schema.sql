create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 2 and 24),
  created_at timestamptz not null default now()
);

create unique index if not exists profiles_nickname_lower_unique
  on public.profiles (lower(nickname));

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  room_code text unique,
  mode text not null default 'arena' check (mode in ('arena', 'campaign')),
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null,
  kills integer not null default 0 check (kills >= 0),
  won boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create table if not exists public.campaign_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  stage smallint not null default 1 check (stage between 1 and 6),
  kills integer not null default 0 check (kills >= 0),
  updated_at timestamptz not null default now()
);

create or replace view public.leaderboard
with (security_invoker = true) as
select
  user_id,
  max(nickname) as nickname,
  count(*)::integer as matches_played,
  coalesce(sum(kills), 0)::integer as total_kills,
  count(*) filter (where won)::integer as wins
from public.match_players
group by user_id;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nickname)
  values (
    new.id,
    left(coalesce(nullif(new.raw_user_meta_data ->> 'nickname', ''), nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'Soldado'), 24)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.campaign_progress enable row level security;

drop policy if exists profiles_public_read on public.profiles;
create policy profiles_public_read on public.profiles
  for select using (true);
drop policy if exists profiles_owner_insert on public.profiles;
create policy profiles_owner_insert on public.profiles
  for insert to authenticated with check (auth.uid() = id);
drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists matches_public_read on public.matches;
create policy matches_public_read on public.matches
  for select using (true);
drop policy if exists matches_host_insert on public.matches;
create policy matches_host_insert on public.matches
  for insert to authenticated with check (auth.uid() = created_by);
drop policy if exists matches_host_update on public.matches;
create policy matches_host_update on public.matches
  for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);

drop policy if exists match_players_public_read on public.match_players;
create policy match_players_public_read on public.match_players
  for select using (true);
drop policy if exists match_players_owner_insert on public.match_players;
create policy match_players_owner_insert on public.match_players
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists match_players_owner_update on public.match_players;
create policy match_players_owner_update on public.match_players
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists campaign_progress_owner_read on public.campaign_progress;
create policy campaign_progress_owner_read on public.campaign_progress
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists campaign_progress_owner_insert on public.campaign_progress;
create policy campaign_progress_owner_insert on public.campaign_progress
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists campaign_progress_owner_update on public.campaign_progress;
create policy campaign_progress_owner_update on public.campaign_progress
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select on public.profiles, public.matches, public.match_players to anon, authenticated;
grant insert, update on public.profiles, public.matches, public.match_players to authenticated;
grant select, insert, update on public.campaign_progress to authenticated;
grant select on public.leaderboard to anon, authenticated;

create table if not exists public.guest_matches (
  id uuid primary key default gen_random_uuid(),
  room_code text unique check (room_code is null or room_code ~ '^[0-9]{8}$'),
  mode text not null default 'arena' check (mode in ('arena', 'campaign')),
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  host_player_id uuid not null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.guest_match_players (
  match_id uuid not null references public.guest_matches(id) on delete cascade,
  player_id uuid not null,
  nickname text not null check (char_length(nickname) between 2 and 24),
  kills integer not null default 0 check (kills >= 0),
  won boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (match_id, player_id)
);

create index if not exists guest_matches_open_rooms_idx
  on public.guest_matches (room_code) where status in ('waiting', 'playing');
create index if not exists guest_match_players_player_history_idx
  on public.guest_match_players (player_id, joined_at desc);

create or replace view public.guest_leaderboard
with (security_invoker = true) as
select
  player_id,
  max(nickname) as nickname,
  count(*)::integer as matches_played,
  coalesce(sum(kills), 0)::integer as total_kills,
  count(*) filter (where won)::integer as wins
from public.guest_match_players
group by player_id;

alter table public.guest_matches enable row level security;
alter table public.guest_match_players enable row level security;

drop policy if exists guest_matches_public_read on public.guest_matches;
create policy guest_matches_public_read on public.guest_matches
  for select to anon, authenticated using (true);
drop policy if exists guest_matches_public_insert on public.guest_matches;
create policy guest_matches_public_insert on public.guest_matches
  for insert to anon, authenticated with check (host_player_id is not null);
drop policy if exists guest_matches_public_update on public.guest_matches;
create policy guest_matches_public_update on public.guest_matches
  for update to anon, authenticated using (true) with check (true);

drop policy if exists guest_match_players_public_read on public.guest_match_players;
create policy guest_match_players_public_read on public.guest_match_players
  for select to anon, authenticated using (true);
drop policy if exists guest_match_players_public_insert on public.guest_match_players;
create policy guest_match_players_public_insert on public.guest_match_players
  for insert to anon, authenticated with check (true);
drop policy if exists guest_match_players_public_update on public.guest_match_players;
create policy guest_match_players_public_update on public.guest_match_players
  for update to anon, authenticated using (true) with check (true);

grant select on public.guest_matches, public.guest_match_players to anon, authenticated;
grant insert on public.guest_matches, public.guest_match_players to anon, authenticated;
grant update (status, finished_at) on public.guest_matches to anon, authenticated;
grant update on public.guest_match_players to anon, authenticated;
grant select on public.guest_leaderboard to anon, authenticated;
