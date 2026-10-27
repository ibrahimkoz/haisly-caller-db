SET LOCAL lock_timeout = '5s';
ALTER TABLE public.follow_up_tasks ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK(version > 0);
CREATE FUNCTION public.bump_follow_up_task_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.version = 2147483647 THEN RAISE EXCEPTION 'Task version exhausted'; END IF;
 NEW.version := OLD.version + 1;
 RETURN NEW;
END $$;
CREATE TRIGGER follow_up_task_version BEFORE UPDATE ON public.follow_up_tasks FOR EACH ROW EXECUTE FUNCTION public.bump_follow_up_task_version();
