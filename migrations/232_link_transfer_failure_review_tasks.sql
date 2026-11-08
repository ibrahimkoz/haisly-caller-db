-- A failed transfer can require review after its contact is archived or changes owner.
-- Keep its source link without attaching historical personal data to the current identity.
SET LOCAL lock_timeout='5s';
ALTER TABLE public.follow_up_tasks
 ADD COLUMN caller_transfer_attempt_id bigint,
 ADD CONSTRAINT follow_up_tasks_transfer_attempt_tenant_fk
  FOREIGN KEY(caller_transfer_attempt_id,tenant_id)
  REFERENCES public.caller_transfer_attempts(id,tenant_id) ON DELETE RESTRICT;
ALTER TABLE public.follow_up_tasks DROP CONSTRAINT follow_up_tasks_link_required_check;
ALTER TABLE public.follow_up_tasks ADD CONSTRAINT follow_up_tasks_link_required_check CHECK (
 call_id IS NOT NULL OR case_id IS NOT NULL OR customer_id IS NOT NULL OR lead_id IS NOT NULL
 OR caller_transfer_attempt_id IS NOT NULL
);
CREATE INDEX follow_up_tasks_transfer_attempt_idx ON public.follow_up_tasks(tenant_id,caller_transfer_attempt_id)
 WHERE caller_transfer_attempt_id IS NOT NULL;
COMMENT ON COLUMN public.follow_up_tasks.caller_transfer_attempt_id IS 'Internal source of transfer failure review tasks, including tasks deliberately detached from a changed or archived contact identity.';
