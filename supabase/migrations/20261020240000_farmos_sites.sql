-- Shai Hills sites for Katamansu Spice Farm.
-- Run after 20261020220000_expenses.sql.
-- Older rows may still say main or north. The app shows those as the two sites.

insert into public.sites (id, name)
values
  ('piggery', 'Piggery Site'),
  ('cattle_poultry', 'Cattle/Poultry Site')
on conflict (id) do nothing;
