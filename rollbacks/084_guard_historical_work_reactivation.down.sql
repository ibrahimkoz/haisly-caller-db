DROP TRIGGER calls_guard_identity_reactivation ON public.calls;
DROP TRIGGER call_sessions_guard_identity_reactivation ON public.call_sessions;
DROP FUNCTION public.guard_historical_call_reactivation();
DO $$ DECLARE tab text; BEGIN
 FOREACH tab IN ARRAY ARRAY['cases','leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references'] LOOP
  EXECUTE format('DROP TRIGGER %I ON public.%I',tab||'_guard_reactivation',tab);
 END LOOP;
END $$;
DROP FUNCTION public.guard_historical_work_reactivation();
