SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_callback_review_actions) THEN RAISE EXCEPTION 'Rollback would lose callback review provenance'; END IF; END $$;
DROP TABLE public.caller_callback_review_actions;
DROP FUNCTION public.guard_callback_review_action();
