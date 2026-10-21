-- Expenses for Katamansu Spice Farm.
-- Run after 20261020210000_farm_operations.sql.
-- Workers cannot read or write this table.

create table public.expenses (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  happened_on date not null,
  category text not null check (
    category in ('feed', 'vet', 'labour', 'transport', 'fuel', 'repairs', 'other')
  ),
  amount_cedis numeric(12, 2) not null check (amount_cedis > 0),
  note text not null default '',
  quantity_kg numeric(12, 2),
  feed_type text,
  animal_tag text,
  people integer,
  days numeric(8, 2),
  litres numeric(12, 2),
  detail text,
  location_id text not null references public.sites (id),
  updated_at timestamptz not null default now()
);

alter table public.expenses enable row level security;

create policy "managers read expenses"
  on public.expenses for select to authenticated
  using (public.farm_role() in ('admin', 'manager'));

create policy "managers write expenses"
  on public.expenses for insert to authenticated
  with check (public.farm_role() in ('admin', 'manager') and auth.uid() = user_id);

grant select, insert, update, delete on public.expenses to authenticated;
