-- Sprint 1 animal register for Shai Hills Farm OS.
-- Run this in the Supabase SQL editor before signing in from the app.
-- Breeding, health, feed, mortality, sales, and sync tables are later sprints.

create table public.animals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tag text not null,
  species text not null check (species in ('pig', 'cattle', 'goat', 'poultry')),
  sex text not null check (sex in ('female', 'male')),
  status text not null check (status in ('on_farm', 'sold', 'dead')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint animals_tag_not_blank check (char_length(btrim(tag)) > 0)
);

create unique index animals_user_tag_lower
  on public.animals (user_id, lower(tag));

alter table public.animals enable row level security;

create policy "owners read own animals"
  on public.animals
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "owners insert own animals"
  on public.animals
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "owners update own animals"
  on public.animals
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "owners delete own animals"
  on public.animals
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.animals to authenticated;
