-- Farm book and the 8-person cap for Katamansu Spice Farm.
-- Run this in the Supabase SQL editor after the animals migration.

create table public.farm_entries (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('health', 'feed', 'breeding', 'milk', 'sale', 'death')),
  happened_on date not null,
  animal_id uuid references public.animals (id) on delete set null,
  animal_tag text,
  note text not null,
  amount numeric(12, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint farm_entries_note_length check (
    char_length(btrim(note)) > 0 and char_length(note) <= 200
  ),
  constraint farm_entries_amount_check check (
    (
      kind in ('milk', 'sale')
      and amount is not null
      and amount > 0
      and (
        (kind = 'milk' and amount <= 2000)
        or (kind = 'sale' and amount <= 1000000)
      )
    )
    or (
      kind in ('health', 'feed', 'breeding', 'death')
      and amount is null
    )
  ),
  constraint farm_entries_animal_check check (
    (
      kind in ('sale', 'death')
      and animal_tag is not null
      and char_length(btrim(animal_tag)) > 0
    )
    or kind in ('health', 'feed', 'breeding', 'milk')
  )
);

create index farm_entries_user_day
  on public.farm_entries (user_id, happened_on desc);

alter table public.farm_entries enable row level security;

create policy "owners read own book"
  on public.farm_entries
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "owners insert own book"
  on public.farm_entries
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "owners update own book"
  on public.farm_entries
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "owners delete own book"
  on public.farm_entries
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.farm_entries to authenticated;

-- The app asks this before creating an account. It returns only yes or no.
create or replace function public.farm_has_room()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select count(*) from auth.users) < 8;
$$;

revoke all on function public.farm_has_room() from public;
grant execute on function public.farm_has_room() to anon, authenticated;

-- Blocks the 9th account even if the app check is skipped.
create or replace function public.limit_farm_accounts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from auth.users) >= 8 then
    raise exception 'This farm already has 8 people. Ask the owner before adding another.';
  end if;
  return new;
end;
$$;

revoke all on function public.limit_farm_accounts() from public;

drop trigger if exists limit_farm_accounts on auth.users;
create trigger limit_farm_accounts
  before insert on auth.users
  for each row
  execute function public.limit_farm_accounts();
