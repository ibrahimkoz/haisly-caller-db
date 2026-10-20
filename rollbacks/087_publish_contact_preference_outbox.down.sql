-- Pending/delivered events are intentionally retained. Disable preference writers before rollback.
DROP TRIGGER contact_change_events_publish_preference ON public.contact_change_events;
DROP FUNCTION public.publish_contact_preference_event();
