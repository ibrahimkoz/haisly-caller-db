SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_teams) THEN RAISE EXCEPTION 'Cannot roll back nonempty caller teams'; END IF;
END $$;
DROP TABLE public.caller_team_members;
DROP FUNCTION public.caller_guard_team_member();
DROP TABLE public.caller_teams;
DROP FUNCTION public.caller_guard_team();
