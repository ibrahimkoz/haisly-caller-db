SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_task_notification_outbox (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL,
 task_id bigint NOT NULL,
 task_version integer NOT NULL CHECK(task_version>0),
 assignee_user_id bigint,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','succeeded','skipped','dead_letter')),
 attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 5),
 available_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 recipient_count integer NOT NULL DEFAULT 0 CHECK(recipient_count>=0),
 last_error_code text CHECK(last_error_code IS NULL OR last_error_code='delivery_failed'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,task_id,task_version),
 FOREIGN KEY(task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(assignee_user_id,tenant_id) REFERENCES public.tenant_memberships(user_id,tenant_id) ON DELETE RESTRICT,
 CHECK((status IN ('succeeded','skipped'))=(completed_at IS NOT NULL)),
 CHECK(status<>'dead_letter' OR attempt_count=5)
);
CREATE INDEX caller_task_notification_pending_idx ON public.caller_task_notification_outbox(tenant_id,available_at,id) WHERE status='pending';
