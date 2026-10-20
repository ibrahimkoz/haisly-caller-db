-- Session-authenticated mutations are tenant-wide, not runtime-environment scoped.
CREATE TABLE public.tenant_mutation_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
 actor_user_id bigint NOT NULL,
 scope text NOT NULL CHECK (length(scope) BETWEEN 1 AND 200),
 idempotency_key text NOT NULL CHECK (length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
 response_body jsonb NOT NULL CHECK (jsonb_typeof(response_body) = 'object'),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days',
 FOREIGN KEY (actor_user_id, tenant_id) REFERENCES public.users(id, tenant_id) ON DELETE CASCADE,
 UNIQUE (tenant_id, actor_user_id, scope, idempotency_key)
);
CREATE INDEX tenant_mutation_receipts_expiry_idx ON public.tenant_mutation_receipts(expires_at);
