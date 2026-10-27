SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_dispatch_intents IN SHARE ROW EXCLUSIVE MODE;
CREATE TABLE public.caller_dispatch_transitions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 version integer NOT NULL CHECK(version>0),
 record_kind text NOT NULL CHECK(record_kind IN ('transition','baseline')),
 from_state text CHECK(from_state IN ('prepared','submitting','uncertain','accepted','ended','rejected','canceled')),
 to_state text NOT NULL CHECK(to_state IN ('prepared','submitting','uncertain','accepted','ended','rejected','canceled')),
 evidence_reference text CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 accepted_at timestamptz,
 ended_at timestamptz,
 end_reason text CHECK(end_reason IN ('completed','no_answer','busy','declined','failed','canceled','voicemail')),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(dispatch_id,version),
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 CHECK(record_kind<>'baseline' OR from_state IS NULL),
 CHECK(record_kind<>'transition' OR ((version=1 AND from_state IS NULL AND to_state='prepared') OR (version>1 AND from_state IS NOT NULL AND from_state<>to_state))),
 CHECK(accepted_at IS NULL OR isfinite(accepted_at)),
 CHECK(ended_at IS NULL OR (accepted_at IS NOT NULL AND isfinite(ended_at) AND ended_at>=accepted_at))
);
CREATE INDEX caller_dispatch_transitions_scope ON public.caller_dispatch_transitions(tenant_id,dispatch_id,version DESC);
-- Existing state is an explicitly labeled baseline, never a fabricated chain of past events.
INSERT INTO public.caller_dispatch_transitions(tenant_id,dispatch_id,version,record_kind,from_state,to_state,evidence_reference,accepted_at,ended_at,end_reason)
 SELECT tenant_id,id,version,'baseline',NULL,state,evidence_reference,accepted_at,ended_at,end_reason FROM public.caller_dispatch_intents;
CREATE FUNCTION public.guard_dispatch_transition_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' OR pg_trigger_depth()<2 THEN
  RAISE EXCEPTION 'Dispatch transition history is trigger-owned and immutable.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_dispatch_transition_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_dispatch_transitions FOR EACH ROW EXECUTE FUNCTION public.guard_dispatch_transition_history();
CREATE FUNCTION public.record_dispatch_transition() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO public.caller_dispatch_transitions(tenant_id,dispatch_id,version,record_kind,from_state,to_state,evidence_reference,accepted_at,ended_at,end_reason)
 VALUES(NEW.tenant_id,NEW.id,NEW.version,'transition',CASE WHEN TG_OP='INSERT' THEN NULL ELSE OLD.state END,NEW.state,NEW.evidence_reference,NEW.accepted_at,NEW.ended_at,NEW.end_reason);
 RETURN NULL;
END;
$$;
CREATE TRIGGER caller_dispatch_history AFTER INSERT OR UPDATE ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.record_dispatch_transition();
