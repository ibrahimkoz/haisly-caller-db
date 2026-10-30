SET LOCAL lock_timeout='5s';
-- Operational rollback only with dispatch disabled; this removes the insert
-- boundary but preserves submission guards and all existing history.
DROP TRIGGER caller_dispatch_active_target_guard ON public.caller_dispatch_intents;
DROP FUNCTION public.guard_dispatch_active_target();
