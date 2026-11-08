SET LOCAL lock_timeout='5s';
-- Refuse rollback while detached review tasks depend on this source link.
ALTER TABLE public.follow_up_tasks DROP CONSTRAINT follow_up_tasks_link_required_check;
ALTER TABLE public.follow_up_tasks ADD CONSTRAINT follow_up_tasks_link_required_check CHECK (
 call_id IS NOT NULL OR case_id IS NOT NULL OR customer_id IS NOT NULL OR lead_id IS NOT NULL
);
ALTER TABLE public.follow_up_tasks DROP COLUMN caller_transfer_attempt_id;
