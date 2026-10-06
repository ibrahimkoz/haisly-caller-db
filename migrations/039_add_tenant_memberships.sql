CREATE TABLE public.tenant_memberships (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'pending_email_verification',
  invited_by_user_id bigint,
  joined_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT tenant_memberships_public_id_unique UNIQUE (public_id),
  CONSTRAINT tenant_memberships_user_tenant_unique UNIQUE (user_id, tenant_id),
  CONSTRAINT tenant_memberships_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_memberships_user_id_fk FOREIGN KEY (user_id)
    REFERENCES public.users (id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_memberships_invited_by_user_id_fk FOREIGN KEY (invited_by_user_id)
    REFERENCES public.users (id)
    ON DELETE SET NULL,
  CONSTRAINT tenant_memberships_status_check CHECK (status IN (
    'pending_email_verification',
    'active',
    'disabled'
  )),
  CONSTRAINT tenant_memberships_joined_timestamp_check CHECK (
    status <> 'active' OR joined_at IS NOT NULL
  )
);

CREATE INDEX tenant_memberships_tenant_status_created_at_idx
  ON public.tenant_memberships (tenant_id, status, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX tenant_memberships_user_status_idx
  ON public.tenant_memberships (user_id, status)
  WHERE deleted_at IS NULL;

INSERT INTO public.tenant_memberships (
  created_at,
  deleted_at,
  joined_at,
  status,
  tenant_id,
  updated_at,
  user_id
)
SELECT
  users.created_at,
  users.deleted_at,
  CASE
    WHEN users.status = 'active' THEN COALESCE(users.email_verified_at, users.created_at)
    ELSE NULL
  END,
  users.status,
  users.tenant_id,
  users.updated_at,
  users.id
FROM public.users
ON CONFLICT ON CONSTRAINT tenant_memberships_user_tenant_unique DO UPDATE SET
  deleted_at = EXCLUDED.deleted_at,
  joined_at = EXCLUDED.joined_at,
  status = EXCLUDED.status,
  updated_at = EXCLUDED.updated_at;

DROP INDEX IF EXISTS public.user_invitations_pending_email_unique_idx;

CREATE UNIQUE INDEX user_invitations_tenant_pending_email_unique_idx
  ON public.user_invitations (tenant_id, invited_email_normalized)
  WHERE status = 'pending';

DO $$
DECLARE
  constraint_record record;
  delete_action text;
  local_columns text;
BEGIN
  FOR constraint_record IN
    SELECT
      con.conname,
      rel.relname AS table_name,
      con.confdeltype,
      (
        SELECT string_agg(quote_ident(att.attname), ', ' ORDER BY key_position.ordinality)
        FROM unnest(con.conkey) WITH ORDINALITY AS key_position(attnum, ordinality)
        JOIN pg_attribute att
          ON att.attrelid = con.conrelid
         AND att.attnum = key_position.attnum
      ) AS local_columns
    FROM pg_constraint con
    JOIN pg_class rel
      ON rel.oid = con.conrelid
    JOIN pg_namespace nsp
      ON nsp.oid = rel.relnamespace
    WHERE con.contype = 'f'
      AND nsp.nspname = 'public'
      AND con.confrelid = 'public.users'::regclass
      AND con.confkey = ARRAY[
        (SELECT attnum FROM pg_attribute WHERE attrelid = 'public.users'::regclass AND attname = 'id'),
        (SELECT attnum FROM pg_attribute WHERE attrelid = 'public.users'::regclass AND attname = 'tenant_id')
      ]::smallint[]
  LOOP
    local_columns := constraint_record.local_columns;
    delete_action := CASE constraint_record.confdeltype
      WHEN 'a' THEN 'NO ACTION'
      WHEN 'r' THEN 'RESTRICT'
      WHEN 'c' THEN 'CASCADE'
      WHEN 'n' THEN 'SET NULL'
      WHEN 'd' THEN 'SET DEFAULT'
      ELSE 'NO ACTION'
    END;

    EXECUTE format(
      'ALTER TABLE public.%I DROP CONSTRAINT %I',
      constraint_record.table_name,
      constraint_record.conname
    );

    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES public.tenant_memberships (user_id, tenant_id) ON DELETE %s',
      constraint_record.table_name,
      constraint_record.conname,
      local_columns,
      delete_action
    );
  END LOOP;
END $$;
