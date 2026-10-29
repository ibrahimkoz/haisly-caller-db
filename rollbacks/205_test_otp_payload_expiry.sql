SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_test_otp_deliveries WHERE payload_erased_at IS NOT NULL) THEN
 RAISE EXCEPTION 'Cannot rollback expired OTP payload erasure history'; END IF; END $$;
DROP INDEX public.caller_test_otp_expired_payload_idx;
ALTER TABLE public.caller_test_otp_deliveries DROP CONSTRAINT caller_test_otp_payload_lifecycle;
ALTER TABLE public.caller_test_otp_deliveries DROP COLUMN payload_erased_at;
ALTER TABLE public.caller_test_otp_deliveries ADD CONSTRAINT caller_test_otp_payload_state CHECK(
 (state IN ('pending','submitting','uncertain') AND ciphertext IS NOT NULL AND encryption_iv IS NOT NULL AND encryption_tag IS NOT NULL)
 OR (state IN ('sent','failed','canceled') AND ciphertext IS NULL AND encryption_iv IS NULL AND encryption_tag IS NULL));
CREATE OR REPLACE FUNCTION public.guard_test_otp_delivery() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'Test OTP delivery history is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'pending' OR NEW.version<>1 OR NEW.provider_message_ref IS NOT NULL OR NEW.evidence_reference IS NOT NULL THEN
   RAISE EXCEPTION 'Test OTP delivery must start pending' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.caller_test_number_challenges b JOIN public.otp_challenges o ON o.id=b.otp_challenge_id AND o.tenant_id=b.tenant_id
   JOIN public.caller_test_numbers n ON n.id=b.test_number_id AND n.tenant_id=b.tenant_id
   WHERE b.id=NEW.challenge_binding_id AND b.tenant_id=NEW.tenant_id AND o.public_id=NEW.request_key AND o.purpose='caller_test_number'
    AND o.status='pending' AND o.expires_at=NEW.expires_at AND o.expires_at>clock_timestamp() AND n.state='active') THEN
   RAISE EXCEPTION 'Test OTP delivery requires matching active challenge' USING ERRCODE='23514'; END IF;
  NEW.created_at:=clock_timestamp();
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.challenge_binding_id,NEW.request_key,NEW.key_version,NEW.expires_at,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.challenge_binding_id,OLD.request_key,OLD.key_version,OLD.expires_at,OLD.created_at) THEN
   RAISE EXCEPTION 'Test OTP delivery source is immutable' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.state='pending' AND NEW.state IN ('submitting','canceled')) OR
   (OLD.state='submitting' AND NEW.state IN ('uncertain','sent','failed')) OR
   (OLD.state='uncertain' AND NEW.state IN ('sent','failed'))) THEN
   RAISE EXCEPTION 'Test OTP delivery cannot repeat submission or reopen' USING ERRCODE='23514'; END IF;
  IF NEW.state IN ('sent','failed','canceled') THEN
   NEW.ciphertext:=NULL; NEW.encryption_iv:=NULL; NEW.encryption_tag:=NULL;
  ELSIF (NEW.ciphertext,NEW.encryption_iv,NEW.encryption_tag) IS DISTINCT FROM (OLD.ciphertext,OLD.encryption_iv,OLD.encryption_tag) THEN
   RAISE EXCEPTION 'Test OTP delivery ciphertext is immutable' USING ERRCODE='23514'; END IF;
  NEW.version:=OLD.version+1;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
