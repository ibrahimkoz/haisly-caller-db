SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_task_notification_outbox) THEN RAISE EXCEPTION 'Refusing to discard notification delivery history'; END IF;
END $$;
DROP TABLE public.caller_task_notification_outbox;
