SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.publish_contact_preference_event() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE contact_uuid uuid; contact_version integer;
BEGIN
 IF NEW.event_type NOT IN ('dnc_requested','dnc_revoked','consent_granted','consent_withdrawn','status_changed','identity_changed','archived') THEN RETURN NEW; END IF;
 SELECT public_id,version INTO STRICT contact_uuid,contact_version FROM public.customers
 WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id;
 INSERT INTO public.outbox_events(tenant_id,topic,event_key,payload)
 VALUES(NEW.tenant_id,'caller.contact_preference.changed',NEW.public_id::text,
  jsonb_build_object('schema_version',1,'event_public_id',NEW.public_id,'contact_public_id',contact_uuid,
   'identity_revision',NEW.identity_revision,'contact_version',contact_version,'event_type',NEW.event_type,
   'occurred_at',NEW.occurred_at));
 RETURN NEW;
END $$;
CREATE TRIGGER contact_change_events_publish_preference AFTER INSERT ON public.contact_change_events
 FOR EACH ROW EXECUTE FUNCTION public.publish_contact_preference_event();
