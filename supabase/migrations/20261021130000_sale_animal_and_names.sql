-- A livestock sale can name the animal, its weight, and the extra cost.
-- People can have a name for task assignment.
-- Safe to run more than once.

alter table public.sales
  add column if not exists animal_tag text not null default '',
  add column if not exists weight_kg numeric(12, 2),
  add column if not exists cost_cedis numeric(12, 2);

alter table public.animals
  add column if not exists sale_cost numeric(12, 2);

alter table public.profiles
  add column if not exists display_name text not null default '';
