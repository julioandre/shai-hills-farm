-- One shop receipt can be several expense lines, and a cost can be for every site.
-- Run after 20261021130000_sale_animal_and_names.sql.

insert into public.sites (id, name)
values ('all', 'All sites')
on conflict (id) do nothing;

alter table public.expenses
  add column if not exists receipt_id text not null default '';
