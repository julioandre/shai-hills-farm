-- Herds a worker may open. Empty means every herd.
alter table public.profiles
  add column if not exists herds text[] not null default '{}';
