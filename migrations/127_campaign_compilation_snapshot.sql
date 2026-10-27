SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_snapshots ADD COLUMN content_compilation_snapshot jsonb,
 ADD CONSTRAINT caller_snapshot_compilation_check CHECK (
  content_compilation_snapshot IS NULL OR COALESCE((
   identity_snapshot IS NOT NULL
   AND jsonb_typeof(content_compilation_snapshot) = 'object'
   AND octet_length(content_compilation_snapshot::text) <= 2097152
   AND content_compilation_snapshot ?& ARRAY['content','summary']
   AND (content_compilation_snapshot - 'content' - 'summary') = '{}'::jsonb
   AND jsonb_typeof(content_compilation_snapshot->'summary') = 'object'
   AND (content_compilation_snapshot->'summary') ?& ARRAY['compiler_version','release_certified','status','content_hash','binding_hash','blocker']
   AND content_compilation_snapshot->'summary'->>'compiler_version' = 'caller-content-v1'
   AND content_compilation_snapshot->'summary'->'release_certified' = 'false'::jsonb
   AND (
    (content_compilation_snapshot->'summary'->>'status' = 'compiled'
     AND jsonb_typeof(content_compilation_snapshot->'content') = 'object'
     AND content_compilation_snapshot->'content'->>'compiler_version' = 'caller-content-v1'
     AND content_compilation_snapshot->'content'->'identity' = identity_snapshot
     AND content_compilation_snapshot->'summary'->>'content_hash' ~ '^[a-f0-9]{64}$'
     AND content_compilation_snapshot->'summary'->>'binding_hash' ~ '^[a-f0-9]{64}$'
     AND content_compilation_snapshot->'summary'->'blocker' = 'null'::jsonb)
    OR
    (content_compilation_snapshot->'summary'->>'status' = 'blocked'
     AND content_compilation_snapshot->'content' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->'content_hash' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->'binding_hash' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->>'blocker' IN ('caller_snapshot_identity_missing','caller_base_instructions_required','caller_content_invalid'))
   )
  ), false)
 );
