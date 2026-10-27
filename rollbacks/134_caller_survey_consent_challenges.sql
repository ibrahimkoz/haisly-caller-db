SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_consent_challenges) THEN
  RAISE EXCEPTION 'Cannot roll back nonempty survey consent history';
 END IF;
END $$;
DROP TABLE public.caller_survey_consent_challenges;
DROP FUNCTION public.caller_guard_survey_consent_challenge();
ALTER TABLE public.caller_runtime_release_bindings DROP CONSTRAINT caller_runtime_binding_id_tenant_unique;
