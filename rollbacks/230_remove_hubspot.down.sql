DO $$ BEGIN
  RAISE EXCEPTION 'HubSpot removal cannot restore deleted credentials or records; restore the pre-230 backup instead';
END $$;
