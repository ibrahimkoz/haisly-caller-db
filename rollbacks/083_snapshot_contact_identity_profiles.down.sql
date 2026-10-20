DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.contact_identity_revisions WHERE profile_snapshot IS NOT NULL) THEN
  RAISE EXCEPTION 'Archived identity profiles exist; use a forward fix';
 END IF;
END $$;
DROP TRIGGER contact_identity_revisions_snapshot_profile ON public.contact_identity_revisions;
DROP FUNCTION public.snapshot_contact_identity_profile();
ALTER TABLE public.contact_identity_revisions DROP COLUMN profile_snapshot;
