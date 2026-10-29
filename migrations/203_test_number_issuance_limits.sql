SET LOCAL lock_timeout='5s';
CREATE INDEX caller_test_number_challenge_rate_idx ON public.caller_test_number_challenges(tenant_id,created_at DESC);
CREATE OR REPLACE FUNCTION public.guard_test_number_challenge() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Test ownership challenge binding is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 IF NOT EXISTS(SELECT 1 FROM public.caller_test_numbers n JOIN public.otp_challenges o ON o.id=NEW.otp_challenge_id AND o.tenant_id=n.tenant_id
  WHERE n.id=NEW.test_number_id AND n.tenant_id=NEW.tenant_id AND n.state='active'
  AND o.user_id=NEW.owner_user_id AND o.purpose='caller_test_number' AND o.delivery_channel='sms'
  AND o.destination_hash=NEW.destination_hash AND o.status='pending' AND o.attempt_count=0 AND o.verified_at IS NULL
  AND o.expires_at>clock_timestamp()) THEN
  RAISE EXCEPTION 'Test ownership challenge source binding is invalid' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id=ur.role_id
  JOIN public.users u ON u.id=ur.user_id JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=ur.tenant_id
  JOIN public.tenants t ON t.id=ur.tenant_id
  WHERE ur.tenant_id=NEW.tenant_id AND ur.user_id=NEW.owner_user_id AND ur.status='active' AND r.status='active' AND r.code='owner'
   AND u.status='active' AND u.deleted_at IS NULL AND m.status='active' AND m.deleted_at IS NULL AND t.status='active' AND t.deleted_at IS NULL) THEN
  RAISE EXCEPTION 'Test ownership challenge requires an active tenant owner' USING ERRCODE='23514'; END IF;
 -- Count by canonical number across revoked/re-enrolled identities. Failed,
 -- expired and canceled challenges still consume issuance quota.
 IF EXISTS(SELECT 1 FROM public.caller_test_number_challenges b JOIN public.caller_test_numbers old_n ON old_n.id=b.test_number_id AND old_n.tenant_id=b.tenant_id
   JOIN public.caller_test_numbers current_n ON current_n.id=NEW.test_number_id AND current_n.tenant_id=NEW.tenant_id
   WHERE b.tenant_id=NEW.tenant_id AND old_n.canonical_phone=current_n.canonical_phone AND b.created_at>clock_timestamp()-interval '60 seconds') THEN
  RAISE EXCEPTION 'Test verification resend cooldown has not elapsed' USING ERRCODE='23514'; END IF;
 IF (SELECT count(*) FROM public.caller_test_number_challenges b JOIN public.caller_test_numbers old_n ON old_n.id=b.test_number_id AND old_n.tenant_id=b.tenant_id
   JOIN public.caller_test_numbers current_n ON current_n.id=NEW.test_number_id AND current_n.tenant_id=NEW.tenant_id
   WHERE b.tenant_id=NEW.tenant_id AND old_n.canonical_phone=current_n.canonical_phone AND b.created_at>clock_timestamp()-interval '24 hours')>=5 THEN
  RAISE EXCEPTION 'Test verification number daily request limit reached' USING ERRCODE='23514'; END IF;
 IF (SELECT count(*) FROM public.caller_test_number_challenges WHERE tenant_id=NEW.tenant_id AND created_at>clock_timestamp()-interval '24 hours')>=20 THEN
  RAISE EXCEPTION 'Test verification tenant daily request limit reached' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
