-- Extra facts for an expense, chosen by category.
-- Feed stores kilos, vet stores the animal, labour stores people and days,
-- fuel stores litres, and transport or repairs store a short detail.
-- Safe to run after 20261020220000_expenses.sql, including a copy that
-- already has these columns.

alter table public.expenses
  add column if not exists quantity_kg numeric(12, 2),
  add column if not exists feed_type text,
  add column if not exists animal_tag text,
  add column if not exists people integer,
  add column if not exists days numeric(8, 2),
  add column if not exists litres numeric(12, 2),
  add column if not exists detail text;
