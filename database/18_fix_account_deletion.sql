-- =====================================================================
-- EEDB - 18 FIX ACCOUNT DELETION
-- Problem: deleting an auth user sets seller_id/recorded_by to NULL (ON DELETE SET NULL),
-- and the guard triggers raised "seller_id cannot be changed" / "confirmed payment ... cannot be changed".
-- Fix: eedb_delete_my_account() sets a transaction-local flag; guards skip only when it is set.
-- Run AFTER 17_play_store_compliance.sql, on the PRODUCTION project (Supabase SQL Editor).
-- =====================================================================

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

  -- tell the guard triggers that this is an account deletion (transaction-local)
  perform set_config('eedb.deleting_account', 'on', true);

  delete from auth.users where id = uid;
end $$;
revoke all on function public.eedb_delete_my_account() from public, anon;
grant execute on function public.eedb_delete_my_account() to authenticated;

-- Listing guard: skip during account deletion
create or replace function public.eedb_lock_listing_status()
returns trigger
language plpgsql
as $$
begin
  if current_setting('eedb.deleting_account', true) = 'on' then
    return new;
  end if;

  -- SQL editor / service role (no JWT user) and admins are unrestricted.
  if auth.uid() is null or public.eedb_is_listing_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending_review';
    return new;
  end if;

  if new.seller_id is distinct from old.seller_id then
    raise exception 'seller_id cannot be changed';
  end if;

  if new.status is distinct from old.status
     and new.status not in ('pending_review','hidden','sold','rented') then
    raise exception 'Only an admin can set status to %', new.status;
  end if;
  return new;
end;
$$;

-- Payment guard: skip during account deletion
create or replace function public.eedb_payment_guard() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if current_setting('eedb.deleting_account', true) = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is not null and not public.eedb_payment_admin(new.city_id) then
      new.status := 'pending'; new.confirmed_by := null; new.confirmed_at := null;
      new.recorded_by := auth.uid();
      new.agent_id := auth.uid();
    elsif new.status = 'confirmed' then
      new.confirmed_by := coalesce(new.confirmed_by, auth.uid()); new.confirmed_at := coalesce(new.confirmed_at, now());
    end if;
    return new;
  end if;
  if old.status = 'confirmed' and auth.uid() is not null and not public.eedb_is_super_admin() then
    raise exception 'A confirmed payment can only be changed by Super Admin';
  end if;
  if old.status = 'confirmed' and (new.amount is distinct from old.amount or new.city_id is distinct from old.city_id or new.kind is distinct from old.kind) and auth.uid() is not null then
    raise exception 'Amount, city and type of a confirmed payment cannot be changed';
  end if;
  if new.status is distinct from old.status then
    new.confirmed_by := auth.uid(); new.confirmed_at := now();
  end if;
  return new;
end $$;
