SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_test_dispatch_ownership() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND NOT (OLD.state='prepared' AND NEW.state='submitting') THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM 1 FROM public.caller_test_numbers n WHERE n.id=NEW.test_number_id AND n.tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT EXISTS(
  SELECT 1 FROM public.caller_test_number_challenges b
  JOIN public.caller_test_numbers n ON n.id=b.test_number_id AND n.tenant_id=b.tenant_id
  JOIN public.otp_challenges o ON o.id=b.otp_challenge_id AND o.tenant_id=b.tenant_id
    AND o.user_id=b.owner_user_id AND o.destination_hash=b.destination_hash
  WHERE b.tenant_id=NEW.tenant_id AND n.id=NEW.test_number_id AND n.state='active'
    AND n.canonical_phone=NEW.canonical_phone AND o.purpose='caller_test_number' AND o.delivery_channel='sms'
    AND o.status='verified' AND o.verified_at IS NOT NULL AND o.verified_at>=b.created_at
    AND o.verified_at<o.expires_at AND o.attempt_count<o.max_attempts
 ) THEN RAISE EXCEPTION 'Test dispatch requires verified enrollment ownership' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_01_test_dispatch_ownership BEFORE INSERT OR UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_ownership();
COMMENT ON FUNCTION public.guard_test_dispatch_ownership() IS 'Require active enrollment-bound consumed OTP proof for new test intents and first submission. No retroactive rewrite of existing history; no provider send authority.';
