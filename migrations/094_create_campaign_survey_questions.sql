SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_survey_questions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 campaign_version_id bigint NOT NULL,
 question_key text NOT NULL CHECK (question_key ~ '^[A-Za-z][A-Za-z0-9_-]{0,63}$'),
 position integer NOT NULL CHECK (position BETWEEN 1 AND 100),
 definition jsonb NOT NULL CHECK (jsonb_typeof(definition)='object' AND octet_length(definition::text)<=2097152),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id,tenant_id),
 UNIQUE (campaign_version_id,question_key),
 CONSTRAINT caller_survey_question_position UNIQUE (campaign_version_id,position) DEFERRABLE INITIALLY DEFERRED,
 CONSTRAINT caller_survey_question_key_matches CHECK (definition ? 'key' AND jsonb_typeof(definition->'key')='string' AND definition->>'key'=question_key),
 FOREIGN KEY (campaign_version_id,tenant_id) REFERENCES public.caller_campaign_versions(id,tenant_id) ON DELETE CASCADE
);
CREATE INDEX caller_survey_questions_tenant_version_idx ON public.caller_survey_questions(tenant_id,campaign_version_id);
