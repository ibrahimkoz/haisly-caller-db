SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_versions
 ADD COLUMN outbound_phone_number_id bigint,
 ADD CONSTRAINT caller_campaign_outbound_phone_fk FOREIGN KEY(outbound_phone_number_id,tenant_id) REFERENCES public.phone_numbers(id,tenant_id) ON DELETE RESTRICT;
CREATE INDEX caller_campaign_outbound_phone_idx ON public.caller_campaign_versions(tenant_id,outbound_phone_number_id) WHERE outbound_phone_number_id IS NOT NULL;
