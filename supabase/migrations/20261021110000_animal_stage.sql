-- Pig and cattle class: grower, sow, boar, heifer, dairy, bull, or cow.
alter table public.animals
  add column if not exists stage text;
