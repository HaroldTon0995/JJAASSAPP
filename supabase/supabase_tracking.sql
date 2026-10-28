-- Run this once in the Supabase SQL editor to enable live delivery tracking.

create table if not exists public.driver_locations (
  order_id   text primary key,
  driver_id  text,
  lat        double precision not null,
  lng        double precision not null,
  updated_at timestamptz not null default now()
);

-- Allow the app (anon key) to read and write locations.
-- Tighten these policies if you add real Supabase Auth.
alter table public.driver_locations enable row level security;

drop policy if exists "driver_locations read"   on public.driver_locations;
drop policy if exists "driver_locations insert" on public.driver_locations;
drop policy if exists "driver_locations update" on public.driver_locations;

create policy "driver_locations read"   on public.driver_locations for select using (true);
create policy "driver_locations insert" on public.driver_locations for insert with check (true);
create policy "driver_locations update" on public.driver_locations for update using (true);

-- Enable realtime so customers/admins see the driver and orders update instantly.
alter table public.orders add column if not exists "deliveryNote" text;
alter publication supabase_realtime add table public.driver_locations;
alter publication supabase_realtime add table public.orders;
