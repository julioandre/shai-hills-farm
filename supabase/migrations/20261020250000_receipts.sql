-- Supplier and receipt flag on an expense.
-- Run after 20261020240000_farmos_sites.sql.

alter table public.expenses
  add column if not exists supplier text not null default '',
  add column if not exists has_receipt boolean not null default false;
