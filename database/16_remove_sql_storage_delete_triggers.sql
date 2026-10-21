-- =====================================================================
-- 16: Supabase does not allow DELETE on storage.objects with SQL
--     ("Direct deletion from storage tables is not allowed").
--     Remove the triggers from 12 and 15 that tried to do it.
--     Photo / CV files are now removed by the app through the Storage API
--     before the listing row is deleted.
-- Run once in the Supabase SQL editor after 01..15. Safe to re-run.
-- =====================================================================
begin;

drop trigger if exists eedb_property_photo_file_cleanup on public.property_images;
drop trigger if exists eedb_marketplace_photo_cleanup on public.marketplace_items;
drop trigger if exists eedb_car_photo_cleanup on public.cars;
drop trigger if exists eedb_job_cv_file_cleanup on public.job_applications;

drop function if exists public.eedb_delete_property_photo_file();
drop function if exists public.eedb_delete_listing_photos_from_urls();
drop function if exists public.eedb_delete_job_cv_file();

commit;
