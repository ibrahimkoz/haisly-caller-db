-- Never silently discard configured tenant policy, even an explicit deny-all revision.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.caller_knowledge_https_policies) THEN
    RAISE EXCEPTION 'HTTPS policy rollback requires an explicit policy backup/removal plan';
  END IF;
END $$;
DROP TABLE public.caller_knowledge_https_policies;
DROP FUNCTION public.caller_guard_https_policy();
DROP FUNCTION public.caller_valid_https_origins(text[]);
