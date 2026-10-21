-- Katamansu Spice Farm operations.
-- Run after 20261020180000_farm_book.sql.
-- One shared herd, roles, feed, breeding, health, weights, sales, milk, and land.

-- The 8-person stop is retired. An admin assigns roles instead.
drop trigger if exists limit_farm_accounts on auth.users;

create or replace function public.farm_has_room()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select true;
$$;

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  phone text,
  role text not null default 'worker' check (role in ('admin', 'manager', 'worker')),
  created_at timestamptz not null default now()
);

create table public.sites (
  id text primary key,
  name text not null
);

-- Real yards are added in 20261020240000_farmos_sites.sql.
-- All sites is added in 20261021140000_expense_receipt.sql.

alter table public.animals drop constraint if exists animals_status_check;
alter table public.animals
  add constraint animals_status_check
  check (status in ('on_farm', 'sold', 'dead', 'culled'));

alter table public.animals
  add column if not exists breed text,
  add column if not exists date_of_birth date,
  add column if not exists mother_id uuid references public.animals (id),
  add column if not exists father_id uuid references public.animals (id),
  add column if not exists weight_kg numeric(8, 2),
  add column if not exists location_id text references public.sites (id);

drop index if exists public.animals_user_tag_lower;
create unique index if not exists animals_tag_lower
  on public.animals (lower(tag));

create table public.births (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  species text not null check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry')),
  dam_tag text not null,
  sire_tag text,
  born_alive integer not null check (born_alive >= 0),
  stillborn integer not null check (stillborn >= 0),
  location_id text not null references public.sites (id),
  updated_at timestamptz not null default now()
);

create table public.mortalities (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  animal_tag text not null,
  species text not null check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry')),
  cause text not null,
  location_id text not null references public.sites (id),
  age_days integer,
  updated_at timestamptz not null default now()
);

create table public.feed_purchases (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  supplier text not null,
  feed_type text not null,
  cost_cedis numeric(12, 2) not null check (cost_cedis > 0),
  quantity_kg numeric(12, 2) not null check (quantity_kg > 0),
  location_id text not null references public.sites (id),
  updated_at timestamptz not null default now()
);

create table public.feed_uses (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  location_id text not null references public.sites (id),
  species text not null check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry')),
  feed_type text not null,
  quantity_kg numeric(12, 2) not null check (quantity_kg > 0),
  updated_at timestamptz not null default now()
);

create table public.breeding_services (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  species text not null check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry')),
  dam_tag text not null,
  sire_tag text,
  service_kind text not null check (service_kind in ('natural', 'ai')),
  heat_on date,
  served_on date not null,
  expected_on date not null,
  actual_on date,
  born_alive integer,
  stillborn integer,
  weaned integer,
  pregnancy text check (pregnancy in ('open', 'pregnant')),
  breed text,
  updated_at timestamptz not null default now()
);

create table public.health_events (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  animal_tag text not null,
  kind text not null check (kind in ('treatment', 'deworm', 'vaccine', 'vet')),
  happened_on date not null,
  next_due date,
  note text not null,
  updated_at timestamptz not null default now()
);

create table public.weight_records (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  animal_tag text not null,
  species text not null check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry')),
  weighed_on date not null,
  weight_kg numeric(8, 2) not null check (weight_kg > 0),
  updated_at timestamptz not null default now()
);

create table public.sales (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  kind text not null check (kind in ('livestock', 'poultry', 'milk', 'feed', 'breeding_stock')),
  enterprise text not null check (enterprise in ('pig', 'beef', 'dairy', 'poultry', 'goat', 'general')),
  location_id text not null references public.sites (id),
  amount_cedis numeric(12, 2) not null check (amount_cedis > 0),
  quantity numeric(12, 2),
  updated_at timestamptz not null default now()
);

create table public.milk_yields (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  cow_tag text not null,
  morning_litres numeric(8, 2) not null check (morning_litres >= 0),
  evening_litres numeric(8, 2) not null check (evening_litres >= 0),
  updated_at timestamptz not null default now()
);

create table public.land_parcels (
  id text primary key,
  name text not null,
  land_use text not null check (land_use in ('pasture', 'maize', 'soybean', 'napier', 'fallow')),
  acres numeric(8, 2) not null check (acres >= 0),
  yield_note text not null default ''
);

insert into public.land_parcels (id, name, land_use, acres) values
  ('pasture', 'Pasture', 'pasture', 0),
  ('maize', 'Maize', 'maize', 0),
  ('soybean', 'Soybean', 'soybean', 0),
  ('napier', 'Napier grass', 'napier', 0),
  ('fallow', 'Fallow', 'fallow', 0);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null,
  unique (user_id, token)
);

create or replace function public.farm_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where user_id = auth.uid();
$$;

revoke all on function public.farm_role() from public;
grant execute on function public.farm_role() to authenticated;

create or replace function public.create_farm_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_role text;
begin
  if (select count(*) from public.profiles) = 0 then
    next_role := 'admin';
  else
    next_role := 'worker';
  end if;
  insert into public.profiles (user_id, phone, role)
  values (new.id, new.phone, next_role)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_farm_profile on auth.users;
create trigger create_farm_profile
  after insert on auth.users
  for each row
  execute function public.create_farm_profile();

insert into public.profiles (user_id, phone, role)
select id, phone, 'worker'
from auth.users
on conflict (user_id) do nothing;

update public.profiles
set role = 'admin'
where not exists (select 1 from public.profiles where role = 'admin')
  and user_id = (select user_id from public.profiles order by created_at limit 1);

alter table public.profiles enable row level security;
alter table public.sites enable row level security;
alter table public.births enable row level security;
alter table public.mortalities enable row level security;
alter table public.feed_purchases enable row level security;
alter table public.feed_uses enable row level security;
alter table public.breeding_services enable row level security;
alter table public.health_events enable row level security;
alter table public.weight_records enable row level security;
alter table public.sales enable row level security;
alter table public.milk_yields enable row level security;
alter table public.land_parcels enable row level security;
alter table public.device_tokens enable row level security;

drop policy if exists "owners read own animals" on public.animals;
drop policy if exists "owners insert own animals" on public.animals;
drop policy if exists "owners update own animals" on public.animals;
drop policy if exists "owners delete own animals" on public.animals;
drop policy if exists "owners read own book" on public.farm_entries;
drop policy if exists "owners insert own book" on public.farm_entries;
drop policy if exists "owners update own book" on public.farm_entries;
drop policy if exists "owners delete own book" on public.farm_entries;

create policy "members read animals"
  on public.animals for select to authenticated
  using (public.farm_role() is not null);
create policy "members write animals"
  on public.animals for insert to authenticated
  with check (public.farm_role() is not null and auth.uid() = user_id);
create policy "managers update animals"
  on public.animals for update to authenticated
  using (public.farm_role() in ('admin', 'manager'))
  with check (public.farm_role() in ('admin', 'manager'));
create policy "managers delete animals"
  on public.animals for delete to authenticated
  using (public.farm_role() in ('admin', 'manager'));

create policy "members read book"
  on public.farm_entries for select to authenticated
  using (
    public.farm_role() in ('admin', 'manager')
    or (public.farm_role() = 'worker' and kind <> 'sale')
  );
create policy "members write book"
  on public.farm_entries for insert to authenticated
  with check (
    auth.uid() = user_id
    and (
      public.farm_role() in ('admin', 'manager')
      or (public.farm_role() = 'worker' and kind <> 'sale')
    )
  );
create policy "managers update book"
  on public.farm_entries for update to authenticated
  using (public.farm_role() in ('admin', 'manager'))
  with check (public.farm_role() in ('admin', 'manager'));
create policy "managers delete book"
  on public.farm_entries for delete to authenticated
  using (public.farm_role() in ('admin', 'manager'));

create policy "members read profiles"
  on public.profiles for select to authenticated
  using (public.farm_role() is not null);
create policy "admin updates profiles"
  on public.profiles for update to authenticated
  using (public.farm_role() = 'admin')
  with check (public.farm_role() = 'admin');

create policy "members read sites"
  on public.sites for select to authenticated
  using (public.farm_role() is not null);

-- Daily records: every role can write births, deaths, and feed use.
create policy "members read births" on public.births for select to authenticated using (public.farm_role() is not null);
create policy "members write births" on public.births for insert to authenticated with check (public.farm_role() is not null and auth.uid() = user_id);

create policy "members read deaths" on public.mortalities for select to authenticated using (public.farm_role() is not null);
create policy "members write deaths" on public.mortalities for insert to authenticated with check (public.farm_role() is not null and auth.uid() = user_id);

create policy "members read feed use" on public.feed_uses for select to authenticated using (public.farm_role() is not null);
create policy "members write feed use" on public.feed_uses for insert to authenticated with check (public.farm_role() is not null and auth.uid() = user_id);

-- Money and breeding plans stay with admin and manager.
create policy "managers read purchases" on public.feed_purchases for select to authenticated using (public.farm_role() in ('admin', 'manager'));
create policy "managers write purchases" on public.feed_purchases for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "managers read sales" on public.sales for select to authenticated using (public.farm_role() in ('admin', 'manager'));
create policy "managers write sales" on public.sales for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "members read breeding" on public.breeding_services for select to authenticated using (public.farm_role() is not null);
create policy "managers write breeding" on public.breeding_services for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "members read health" on public.health_events for select to authenticated using (public.farm_role() is not null);
create policy "managers write health" on public.health_events for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "members read weights" on public.weight_records for select to authenticated using (public.farm_role() is not null);
create policy "managers write weights" on public.weight_records for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "members read milk" on public.milk_yields for select to authenticated using (public.farm_role() is not null);
create policy "managers write milk" on public.milk_yields for insert to authenticated with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

create policy "members read land" on public.land_parcels for select to authenticated using (public.farm_role() is not null);

create policy "own tokens" on public.device_tokens for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on public.profiles to authenticated;
grant select on public.sites to authenticated;
grant select, insert, update, delete on public.births to authenticated;
grant select, insert, update, delete on public.mortalities to authenticated;
grant select, insert, update, delete on public.feed_purchases to authenticated;
grant select, insert, update, delete on public.feed_uses to authenticated;
grant select, insert, update, delete on public.breeding_services to authenticated;
grant select, insert, update, delete on public.health_events to authenticated;
grant select, insert, update, delete on public.weight_records to authenticated;
grant select, insert, update, delete on public.sales to authenticated;
grant select, insert, update, delete on public.milk_yields to authenticated;
grant select on public.land_parcels to authenticated;
grant select, insert, update, delete on public.device_tokens to authenticated;

insert into storage.buckets (id, name, public)
values ('farm-files', 'farm-files', false)
on conflict (id) do nothing;

create policy "members read farm files"
  on storage.objects for select to authenticated
  using (bucket_id = 'farm-files' and public.farm_role() is not null);

create policy "managers write farm files"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'farm-files' and public.farm_role() in ('admin', 'manager'));
