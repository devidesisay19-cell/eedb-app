-- =====================================================================
-- EEDB V7 - 17 PLAY STORE COMPLIANCE
--   1) app_settings: support email / phone / company / address, editable by Super Admin
--   2) eedb_delete_my_account(): in-app account deletion required by Google Play
-- Safe to re-run. Adds only; deletes no existing rows.
-- Run in Supabase -> SQL Editor on the PRODUCTION project.
-- =====================================================================

-- 1) Public contact settings ------------------------------------------
create table if not exists public.app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.app_settings enable row level security;

drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings
  for select to anon, authenticated using (true);

drop policy if exists app_settings_write on public.app_settings;
create policy app_settings_write on public.app_settings
  for all to authenticated
  using (public.eedb_is_super_admin())
  with check (public.eedb_is_super_admin());

insert into public.app_settings (key, value) values
  ('company_name',  'Eastern Ethiopia Digital Broker'),
  ('support_email', 'dawitesisay1@gmail.com'),
  ('support_phone', '0981007052'),
  ('address',       'Harar and Dire Dawa, Ethiopia'),
  ('policy_date',   to_char(now() at time zone 'Africa/Addis_Ababa', 'YYYY-MM-DD'))
on conflict (key) do nothing;

create or replace function public.eedb_set_setting(p_key text, p_value text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.eedb_is_super_admin() then
    raise exception 'Only Super Admin can change settings';
  end if;
  if p_key not in ('company_name','support_email','support_phone','address','policy_date') then
    raise exception 'Unknown setting';
  end if;
  insert into public.app_settings(key, value, updated_at, updated_by)
  values (p_key, coalesce(trim(p_value), ''), now(), auth.uid())
  on conflict (key) do update
    set value = excluded.value, updated_at = now(), updated_by = auth.uid();
end $$;
revoke all on function public.eedb_set_setting(text, text) from public, anon;
grant execute on function public.eedb_set_setting(text, text) to authenticated;

-- 2) Delete my account -------------------------------------------------
-- Deleting the auth user cascades to profile, listings, applications, devices,
-- notifications, chat messages (see the ON DELETE CASCADE rules of the schema).
-- Files in Storage are removed by the app through the Storage API BEFORE this call
-- (SQL cannot delete Storage objects).
create or replace function public.eedb_delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  uid uuid := auth.uid();
  r text;
begin
  if uid is null then
    raise exception 'Not logged in';
  end if;

  select role into r from public.profiles where id = uid;

  if r = 'super_admin' and
     (select count(*) from public.profiles where role = 'super_admin' and is_active and id <> uid) = 0 then
    raise exception 'You are the only Super Admin. Create another Super Admin first.';
  end if;

  delete from auth.users where id = uid;
end $$;
revoke all on function public.eedb_delete_my_account() from public, anon;
grant execute on function public.eedb_delete_my_account() to authenticated;
