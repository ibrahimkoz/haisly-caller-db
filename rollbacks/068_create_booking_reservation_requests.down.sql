DROP TABLE IF EXISTS public.booking_reservation_requests;

ALTER TABLE public.ai_call_sessions
  DROP CONSTRAINT IF EXISTS ai_call_sessions_id_tenant_id_unique;

ALTER TABLE public.hotelrunner_reservation_outbox
  DROP CONSTRAINT IF EXISTS hotelrunner_reservation_outbox_id_tenant_id_unique;
