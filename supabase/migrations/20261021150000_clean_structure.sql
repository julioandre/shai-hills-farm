-- Sheep on every species check, farm-wide sales, and no placeholder yards.
-- Safe to run after the earlier migrations, including a database that
-- already has the old checks.

alter table public.births drop constraint if exists births_species_check;
alter table public.births
  add constraint births_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.mortalities drop constraint if exists mortalities_species_check;
alter table public.mortalities
  add constraint mortalities_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.feed_uses drop constraint if exists feed_uses_species_check;
alter table public.feed_uses
  add constraint feed_uses_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.breeding_services drop constraint if exists breeding_services_species_check;
alter table public.breeding_services
  add constraint breeding_services_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.weight_records drop constraint if exists weight_records_species_check;
alter table public.weight_records
  add constraint weight_records_species_check
  check (species in ('pig', 'cattle', 'goat', 'sheep', 'poultry'));

alter table public.sales drop constraint if exists sales_enterprise_check;
alter table public.sales
  add constraint sales_enterprise_check
  check (enterprise in ('pig', 'beef', 'dairy', 'poultry', 'goat', 'general'));

delete from public.sites
where id in ('main', 'north')
  and not exists (
    select 1 from public.animals where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.births where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.mortalities where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.feed_purchases where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.feed_uses where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.sales where location_id in ('main', 'north')
  )
  and not exists (
    select 1 from public.expenses where location_id in ('main', 'north')
  );
