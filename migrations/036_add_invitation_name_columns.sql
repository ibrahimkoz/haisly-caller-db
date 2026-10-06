ALTER TABLE public.user_invitations
  ADD COLUMN invited_first_name text,
  ADD COLUMN invited_last_name text;

ALTER TABLE public.user_invitations
  ADD CONSTRAINT user_invitations_invited_first_name_not_blank_check CHECK (
    invited_first_name IS NULL OR btrim(invited_first_name) <> ''
  ),
  ADD CONSTRAINT user_invitations_invited_last_name_not_blank_check CHECK (
    invited_last_name IS NULL OR btrim(invited_last_name) <> ''
  );
