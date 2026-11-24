create table if not exists public.shared_calendar_entries (
  id text primary key,
  entry_date date not null,
  title text not null,
  type text not null check (type in ('income', 'expense')),
  amount bigint check (amount is null or amount between 1 and 999999999999),
  notes text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists shared_calendar_entries_date_idx
  on public.shared_calendar_entries (entry_date);

alter table public.shared_calendar_entries enable row level security;

drop policy if exists "Anyone can manage shared calendar entries"
  on public.shared_calendar_entries;
create policy "Anyone can manage shared calendar entries"
  on public.shared_calendar_entries for all to anon, authenticated
  using (true)
  with check (true);

create table if not exists public.shared_calendar_rooms (
  room_number text primary key check (room_number in (
    '201호', '202호', '203호', '204호',
    '301호', '302호', '303호', '304호'
  )),
  resident_name text not null default '' check (char_length(resident_name) <= 80),
  phone_number text not null default '' check (char_length(phone_number) <= 30),
  move_in_date date,
  deposit_amount bigint check (deposit_amount is null or deposit_amount between 0 and 999999999999),
  monthly_rent bigint check (monthly_rent is null or monthly_rent between 0 and 999999999999),
  contract_image_path text check (contract_image_path is null or contract_image_path in (
    '201/contract-image', '202/contract-image', '203/contract-image', '204/contract-image',
    '301/contract-image', '302/contract-image', '303/contract-image', '304/contract-image'
  )),
  updated_at timestamptz not null default now()
);

alter table public.shared_calendar_rooms
  add column if not exists phone_number text not null default '';

alter table public.shared_calendar_rooms
  add column if not exists contract_image_path text;

alter table public.shared_calendar_rooms
  drop constraint if exists shared_calendar_rooms_room_number_check;

alter table public.shared_calendar_rooms
  add constraint shared_calendar_rooms_room_number_check
  check (room_number in (
    '201호', '202호', '203호', '204호',
    '301호', '302호', '303호', '304호'
  )) not valid;

delete from public.shared_calendar_rooms
where room_number not in (
  '201호', '202호', '203호', '204호',
  '301호', '302호', '303호', '304호'
);

alter table public.shared_calendar_rooms
  validate constraint shared_calendar_rooms_room_number_check;

alter table public.shared_calendar_rooms
  drop constraint if exists shared_calendar_rooms_contract_image_path_check;

alter table public.shared_calendar_rooms
  add constraint shared_calendar_rooms_contract_image_path_check
  check (contract_image_path is null or contract_image_path in (
    '201/contract-image', '202/contract-image', '203/contract-image', '204/contract-image',
    '301/contract-image', '302/contract-image', '303/contract-image', '304/contract-image'
  )) not valid;

alter table public.shared_calendar_rooms
  validate constraint shared_calendar_rooms_contract_image_path_check;

alter table public.shared_calendar_rooms enable row level security;

drop policy if exists "Anyone can manage shared calendar rooms"
  on public.shared_calendar_rooms;
create policy "Anyone can manage shared calendar rooms"
  on public.shared_calendar_rooms for all to anon, authenticated
  using (true)
  with check (true);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.shared_calendar_entries to anon, authenticated;
grant select, insert, update on public.shared_calendar_rooms to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'misung-contract-images',
  'misung-contract-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

grant usage on schema storage to anon, authenticated;
grant select, insert, update on storage.objects to anon, authenticated;

drop policy if exists "Anyone can read Misung contract images"
  on storage.objects;
create policy "Anyone can read Misung contract images"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'misung-contract-images'
    and name ~ '^(201|202|203|204|301|302|303|304)/contract-image$'
  );

drop policy if exists "Anyone can upload Misung contract images"
  on storage.objects;
create policy "Anyone can upload Misung contract images"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'misung-contract-images'
    and name ~ '^(201|202|203|204|301|302|303|304)/contract-image$'
  );

drop policy if exists "Anyone can replace Misung contract images"
  on storage.objects;
create policy "Anyone can replace Misung contract images"
  on storage.objects for update to anon, authenticated
  using (
    bucket_id = 'misung-contract-images'
    and name ~ '^(201|202|203|204|301|302|303|304)/contract-image$'
  )
  with check (
    bucket_id = 'misung-contract-images'
    and name ~ '^(201|202|203|204|301|302|303|304)/contract-image$'
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'shared_calendar_entries'
    ) then
      alter publication supabase_realtime add table public.shared_calendar_entries;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'shared_calendar_rooms'
    ) then
      alter publication supabase_realtime add table public.shared_calendar_rooms;
    end if;
  end if;
end
$$;
