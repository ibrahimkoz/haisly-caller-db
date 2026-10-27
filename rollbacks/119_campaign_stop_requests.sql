SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_stop_requests) THEN
  RAISE EXCEPTION 'Cannot remove durable campaign stops; forward remediation required';
 END IF;
END $$;
DROP TRIGGER caller_dispatch_campaign_stop_guard ON public.caller_dispatch_intents;
DROP FUNCTION public.guard_dispatch_campaign_stop();
DROP TRIGGER caller_campaign_stop_request_guard ON public.caller_campaign_stop_requests;
DROP FUNCTION public.guard_campaign_stop_request();
DROP TABLE public.caller_campaign_stop_requests;
