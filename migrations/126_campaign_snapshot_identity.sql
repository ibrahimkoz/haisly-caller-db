SET LOCAL lock_timeout = '5s';
-- Legacy snapshots remain unknown; never backfill with today's tenant/agent names.
ALTER TABLE public.caller_campaign_snapshots ADD COLUMN identity_snapshot jsonb,
 ADD CONSTRAINT caller_snapshot_identity_check CHECK (
   identity_snapshot IS NULL OR (
     jsonb_typeof(identity_snapshot) = 'object'
     AND identity_snapshot ?& ARRAY['brand_name', 'assistant_name']
     AND (identity_snapshot - 'brand_name' - 'assistant_name') = '{}'::jsonb
     AND jsonb_typeof(identity_snapshot->'brand_name') = 'string'
     AND char_length(identity_snapshot->>'brand_name') BETWEEN 1 AND 200
     AND jsonb_typeof(identity_snapshot->'assistant_name') IN ('string','null')
     AND (identity_snapshot->'assistant_name' = 'null'::jsonb
          OR char_length(identity_snapshot->>'assistant_name') BETWEEN 1 AND 200)
   )
 );
