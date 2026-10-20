SET LOCAL lock_timeout = '5s';
-- NULL explicitly means that an older archive has no recoverable full profile.
-- Never reconstruct old identity PII from the current owner.
ALTER TABLE public.contact_identity_revisions ADD COLUMN profile_snapshot jsonb
 CHECK(profile_snapshot IS NULL OR jsonb_typeof(profile_snapshot)='object');
CREATE FUNCTION public.snapshot_contact_identity_profile() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person public.customers%ROWTYPE;
BEGIN
 IF TG_OP='UPDATE' THEN
  RAISE EXCEPTION 'Archived identity is immutable' USING ERRCODE='23514', CONSTRAINT='caller_history_identity_guard';
 END IF;
 SELECT * INTO STRICT person FROM public.customers
 WHERE tenant_id=NEW.tenant_id AND id=NEW.customer_id FOR SHARE;
 IF person.identity_revision<>NEW.revision THEN
  RAISE EXCEPTION 'Archive must capture the current identity before transition' USING ERRCODE='23514', CONSTRAINT='caller_history_identity_guard';
 END IF;
 NEW.display_name:=person.display_name;
 NEW.profile_snapshot:=jsonb_build_object(
  'display_name',person.display_name,'first_name',person.first_name,'last_name',person.last_name,
  'title',person.title,'primary_phone',person.primary_phone,'canonical_phone',person.canonical_phone,
  'primary_email',person.primary_email,'notes',person.notes,'metadata',person.metadata,
  'country_code',person.country_code,'contact_timezone',person.contact_timezone,
  'contact_timezone_verified_at',person.contact_timezone_verified_at,
  'contact_status_id',person.contact_status_id,'contact_status_occurred_at',person.contact_status_occurred_at,
  'contact_state',person.contact_state,'status',person.status,'do_not_call_at',person.do_not_call_at);
 RETURN NEW;
END $$;
CREATE TRIGGER contact_identity_revisions_snapshot_profile BEFORE INSERT OR UPDATE ON public.contact_identity_revisions
 FOR EACH ROW EXECUTE FUNCTION public.snapshot_contact_identity_profile();
