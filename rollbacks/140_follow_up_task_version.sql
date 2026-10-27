SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.follow_up_tasks WHERE version > 1) THEN RAISE EXCEPTION 'Refusing to discard task version history'; END IF;
END $$;
DROP TRIGGER follow_up_task_version ON public.follow_up_tasks;
DROP FUNCTION public.bump_follow_up_task_version();
ALTER TABLE public.follow_up_tasks DROP COLUMN version;
