SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_versions
 ADD COLUMN brand_name_override text,
 ADD COLUMN assistant_name_override text,
 ADD CONSTRAINT caller_campaign_brand_override_check CHECK (
   brand_name_override IS NULL OR (
     char_length(brand_name_override) BETWEEN 1 AND 200
     AND brand_name_override = btrim(brand_name_override)
     AND brand_name_override !~ '^[[:space:]]*$'
     AND brand_name_override !~ '[[:cntrl:]]'
   )
 ),
 ADD CONSTRAINT caller_campaign_assistant_override_check CHECK (
   assistant_name_override IS NULL OR (
     char_length(assistant_name_override) BETWEEN 1 AND 200
     AND assistant_name_override = btrim(assistant_name_override)
     AND assistant_name_override !~ '^[[:space:]]*$'
     AND assistant_name_override !~ '[[:cntrl:]]'
   )
 );
