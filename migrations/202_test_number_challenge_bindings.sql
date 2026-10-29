SET LOCAL lock_timeout='5s';
ALTER TABLE public.otp_challenges DROP CONSTRAINT otp_challenges_purpose_check;
ALTER TABLE public.otp_challenges ADD CONSTRAINT otp_challenges_purpose_check CHECK(purpose IN ('login_mfa','email_verification','password_reset','phone_verification','caller_test_number'));
ALTER TABLE public.otp_challenges ADD CONSTRAINT otp_challenges_id_tenant_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_test_number_challenges (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 test_number_id bigint NOT NULL,
 otp_challenge_id bigint NOT NULL UNIQUE,
 owner_user_id bigint NOT NULL,
 destination_hash text NOT NULL CHECK(destination_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(test_number_id,tenant_id) REFERENCES public.caller_test_numbers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(otp_challenge_id,tenant_id) REFERENCES public.otp_challenges(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(owner_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_test_number_challenge_history ON public.caller_test_number_challenges(tenant_id,test_number_id,id DESC);
CREATE FUNCTION public.guard_test_number_challenge() RETURNS trigger LANGUAGE plpgsql AS $$
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
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_test_number_challenge_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_test_number_challenges FOR EACH ROW EXECUTE FUNCTION public.guard_test_number_challenge();
CREATE TRIGGER caller_test_number_challenge_no_truncate BEFORE TRUNCATE ON public.caller_test_number_challenges FOR EACH STATEMENT EXECUTE FUNCTION public.guard_test_number_challenge();
COMMENT ON TABLE public.caller_test_number_challenges IS 'Immutable enrollment-scoped OTP provenance, not verification proof. Dedicated caller purpose avoids account MFA/phone verification reuse. Sender must hash canonical destination using server pepper; no plaintext OTP stored here.';
CREATE FUNCTION public.guard_bound_test_otp() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.caller_test_number_challenges WHERE otp_challenge_id=OLD.id) THEN RETURN NEW; END IF;
 IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.user_id,NEW.purpose,NEW.delivery_channel,NEW.destination_hash,NEW.code_hash,NEW.created_at,NEW.expires_at,NEW.max_attempts)
  IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.user_id,OLD.purpose,OLD.delivery_channel,OLD.destination_hash,OLD.code_hash,OLD.created_at,OLD.expires_at,OLD.max_attempts)
  OR OLD.status<>'pending' OR NEW.attempt_count<OLD.attempt_count OR NEW.attempt_count>OLD.attempt_count+1 THEN
  RAISE EXCEPTION 'Bound test OTP identity cannot change or reset' USING ERRCODE='23514'; END IF;
 IF NEW.status='verified' AND (NEW.verified_at IS NULL OR NEW.verified_at>clock_timestamp() OR NEW.verified_at<NEW.created_at OR NEW.verified_at>=NEW.expires_at OR NEW.attempt_count>=NEW.max_attempts) THEN
  RAISE EXCEPTION 'Bound test OTP verification is expired or exhausted' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_test_bound_otp_guard BEFORE UPDATE ON public.otp_challenges FOR EACH ROW EXECUTE FUNCTION public.guard_bound_test_otp();
