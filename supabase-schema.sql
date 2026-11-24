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
    '201호', '202호', '203호', '204호', '205호',
    '301호', '302호', '303호', '304호', '305호',
    '401호', '402호', '403호', '405호', '406호'
  )),
  resident_name text not null default '' check (char_length(resident_name) <= 80),
  phone_number text not null default '' check (char_length(phone_number) <= 30),
  move_in_date date,
  deposit_amount bigint check (deposit_amount is null or deposit_amount between 0 and 999999999999),
  monthly_rent bigint check (monthly_rent is null or monthly_rent between 0 and 999999999999),
  updated_at timestamptz not null default now()
);

alter table public.shared_calendar_rooms
  add column if not exists phone_number text not null default '';

alter table public.shared_calendar_rooms
  drop constraint if exists shared_calendar_rooms_room_number_check;

alter table public.shared_calendar_rooms
  add constraint shared_calendar_rooms_room_number_check
  check (room_number in (
    '201호', '202호', '203호', '204호', '205호',
    '301호', '302호', '303호', '304호', '305호',
    '401호', '402호', '403호', '405호', '406호'
  )) not valid;

do $$
begin
  if exists (
    select 1 from public.shared_calendar_rooms where room_number = '404호'
  ) or exists (
    select 1 from public.shared_calendar_entries where title = '404호'
  ) then
    if exists (
      select 1 from public.shared_calendar_rooms where room_number = '406호'
    ) then
      raise exception '406호 프로필이 이미 있어 호실 번호를 자동 변경할 수 없습니다.';
    end if;

    update public.shared_calendar_rooms
    set room_number = '406호', updated_at = now()
    where room_number = '405호';

    update public.shared_calendar_rooms
    set room_number = '405호', updated_at = now()
    where room_number = '404호';

    update public.shared_calendar_entries
    set title = '406호'
    where title = '405호';

    update public.shared_calendar_entries
    set title = '405호'
    where title = '404호';
  end if;
end $$;

alter table public.shared_calendar_rooms
  validate constraint shared_calendar_rooms_room_number_check;

insert into public.shared_calendar_rooms (room_number)
values
  ('201호'), ('202호'), ('203호'), ('204호'), ('205호'),
  ('301호'), ('302호'), ('303호'), ('304호'), ('305호'),
  ('401호'), ('402호'), ('403호'), ('405호'), ('406호')
on conflict (room_number) do nothing;

insert into public.shared_calendar_entries (id, entry_date, title, type, amount, notes)
select source.id, source.entry_date, source.title, source.type, source.amount, source.notes
from (values
  ('history-2026-04-21-406-400000', date '2026-04-21', '406호', 'income', 400000::bigint, ''),
  ('history-2026-05-20-406-400000', date '2026-05-20', '406호', 'income', 400000::bigint, ''),
  ('history-2026-06-22-406-400000', date '2026-06-22', '406호', 'income', 400000::bigint, ''),
  ('history-2026-07-21-406-400000', date '2026-07-21', '406호', 'income', 400000::bigint, ''),
  ('history-2026-08-20-406-400000', date '2026-08-20', '406호', 'income', 400000::bigint, ''),
  ('history-2026-09-20-406-400000', date '2026-09-20', '406호', 'income', 400000::bigint, ''),
  ('history-2026-10-20-406-400000', date '2026-10-20', '406호', 'income', 400000::bigint, '')
) as source(id, entry_date, title, type, amount, notes)
where not exists (
  select 1
  from public.shared_calendar_entries existing
  where existing.entry_date = source.entry_date
    and existing.title = source.title
    and existing.type = source.type
    and existing.amount = source.amount
)
on conflict (id) do nothing;

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
