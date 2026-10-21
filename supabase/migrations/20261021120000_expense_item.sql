-- The name and the quantity written on an expense or a sale.
-- Feed still uses quantity_kg. Other costs use quantity.
-- Safe to run more than once.

alter table public.expenses
  add column if not exists item_name text not null default '',
  add column if not exists quantity numeric(12, 2);

alter table public.sales
  add column if not exists item_name text not null default '';
