-- Ubatuba a Dois — backend mínimo para login Google + sincronização
-- Execute no SQL Editor do Supabase UMA vez.
-- Depois: Authentication > Providers > Google > Enable
-- e adicione a URL do GitHub Pages em Authentication > URL Configuration.

create extension if not exists pgcrypto;

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Ubatuba a Dois',
  owner_id uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (trip_id,user_id)
);

create table if not exists public.trip_state (
  trip_id uuid primary key references public.trips(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.trip_state enable row level security;

drop policy if exists "members can read trips" on public.trips;
create policy "members can read trips"
on public.trips for select
using (
  owner_id = auth.uid()
  or exists (
    select 1 from public.trip_members tm
    where tm.trip_id = trips.id and tm.user_id = auth.uid()
  )
);

drop policy if exists "members can read membership" on public.trip_members;
create policy "members can read membership"
on public.trip_members for select
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.trip_members tm2
    where tm2.trip_id = trip_members.trip_id and tm2.user_id = auth.uid()
  )
);

drop policy if exists "members can read trip state" on public.trip_state;
create policy "members can read trip state"
on public.trip_state for select
using (
  exists (
    select 1 from public.trip_members tm
    where tm.trip_id = trip_state.trip_id and tm.user_id = auth.uid()
  )
);

drop policy if exists "members can insert trip state" on public.trip_state;
create policy "members can insert trip state"
on public.trip_state for insert
with check (
  exists (
    select 1 from public.trip_members tm
    where tm.trip_id = trip_state.trip_id and tm.user_id = auth.uid()
  )
);

drop policy if exists "members can update trip state" on public.trip_state;
create policy "members can update trip state"
on public.trip_state for update
using (
  exists (
    select 1 from public.trip_members tm
    where tm.trip_id = trip_state.trip_id and tm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.trip_members tm
    where tm.trip_id = trip_state.trip_id and tm.user_id = auth.uid()
  )
);

-- Create a private shared trip and automatically add creator as owner.
create or replace function public.create_shared_trip(trip_name text default 'Ubatuba a Dois')
returns table(trip_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  new_code text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  loop
    new_code := upper(substr(encode(gen_random_bytes(6),'hex'),1,6));
    exit when not exists(select 1 from public.trips t where t.invite_code = new_code);
  end loop;

  insert into public.trips(name,owner_id,invite_code)
  values(coalesce(trip_name,'Ubatuba a Dois'),auth.uid(),new_code)
  returning id into new_id;

  insert into public.trip_members(trip_id,user_id,role)
  values(new_id,auth.uid(),'owner');

  return query select new_id,new_code;
end;
$$;

-- Join a private trip using its invite code.
create or replace function public.join_shared_trip(invite_code_input text)
returns table(trip_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
  normalized text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  normalized := upper(trim(invite_code_input));

  select t.id into target_id
  from public.trips t
  where t.invite_code = normalized;

  if target_id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.trip_members(trip_id,user_id,role)
  values(target_id,auth.uid(),'member')
  on conflict (trip_id,user_id) do nothing;

  return query select target_id,normalized;
end;
$$;

grant execute on function public.create_shared_trip(text) to authenticated;
grant execute on function public.join_shared_trip(text) to authenticated;

-- Realtime for shared state.
alter table public.trip_state replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.trip_state;
exception
  when duplicate_object then null;
end $$;
