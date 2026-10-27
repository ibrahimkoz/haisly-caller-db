-- Recorded-order keyset history within one tenant opportunity.
CREATE INDEX caller_lead_history_page ON public.lead_events (tenant_id, lead_id, id DESC);
