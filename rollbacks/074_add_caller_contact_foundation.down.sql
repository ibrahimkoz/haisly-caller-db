-- Never erase preferences or new optional-name records during rollback.
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.contact_lists)
 OR EXISTS (SELECT 1 FROM public.contact_change_events)
 OR EXISTS (SELECT 1 FROM public.contact_consents)
 OR EXISTS (SELECT 1 FROM public.contact_identity_revisions)
 OR EXISTS (SELECT 1 FROM public.customers WHERE canonical_phone IS NOT NULL
   OR first_name IS NULL OR last_name IS NULL OR do_not_call_at IS NOT NULL OR archived_at IS NOT NULL
   OR title IS NOT NULL OR country_code IS NOT NULL OR contact_timezone IS NOT NULL
   OR contact_status_id IS NOT NULL OR contact_status_occurred_at IS NOT NULL
   OR contact_state <> 'pending_review' OR identity_revision <> 1 OR version <> 1)
 THEN RAISE EXCEPTION 'Caller contact data exists; retain additive schema and use a forward fix'; END IF;
END $$;
DROP TABLE public.contact_identity_revisions, public.contact_consents, public.contact_change_events, public.contact_list_members, public.contact_lists;
DROP VIEW public.caller_contact_backfill_issues;
ALTER TABLE public.customers
 DROP CONSTRAINT customers_canonical_phone_unique,
 DROP CONSTRAINT customers_ready_identity_check,
 DROP CONSTRAINT customers_contact_timezone_verified_check,
 DROP COLUMN title, DROP COLUMN canonical_phone, DROP COLUMN contact_state,
 DROP COLUMN country_code, DROP COLUMN contact_timezone, DROP COLUMN contact_timezone_verified_at,
 DROP COLUMN contact_status_id, DROP COLUMN contact_status_occurred_at,
 DROP COLUMN identity_revision, DROP COLUMN version, DROP COLUMN archived_at, DROP COLUMN do_not_call_at,
 ALTER COLUMN first_name SET NOT NULL, ALTER COLUMN last_name SET NOT NULL;
DROP INDEX public.customers_caller_page_idx;
DROP TABLE public.contact_statuses;
