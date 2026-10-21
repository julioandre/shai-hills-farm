-- Origin, purchase, and exit details for each animal.
-- Run after 20261020250000_receipts.sql.

alter table public.animals drop constraint if exists animals_species_check;
alter table public.animals
  add constraint animals_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.animals drop constraint if exists animals_status_check;
alter table public.animals
  add constraint animals_status_check
  check (status in ('on_farm', 'sold', 'slaughtered', 'dead', 'culled'));

alter table public.animals
  add column if not exists origin text not null default 'born',
  add column if not exists dairy boolean not null default false,
  add column if not exists mother_tag text,
  add column if not exists father_tag text,
  add column if not exists birth_weight_kg numeric(8, 2),
  add column if not exists birth_location_id text,
  add column if not exists source_farm text,
  add column if not exists supplier_name text,
  add column if not exists purchase_date date,
  add column if not exists purchase_weight_kg numeric(8, 2),
  add column if not exists purchase_price numeric(12, 2),
  add column if not exists transport_cost numeric(12, 2),
  add column if not exists sale_date date,
  add column if not exists sale_weight_kg numeric(8, 2),
  add column if not exists sale_price numeric(12, 2),
  add column if not exists buyer_name text,
  add column if not exists buyer_contact text,
  add column if not exists slaughter_date date,
  add column if not exists live_weight_kg numeric(8, 2),
  add column if not exists carcass_weight_kg numeric(8, 2),
  add column if not exists slaughter_destination text,
  add column if not exists death_date date,
  add column if not exists death_weight_kg numeric(8, 2),
  add column if not exists death_cause text,
  add column if not exists death_note text,
  add column if not exists has_death_photo boolean not null default false,
  add column if not exists cull_date date,
  add column if not exists cull_weight_kg numeric(8, 2),
  add column if not exists cull_reason text;
