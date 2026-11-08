DO $$ BEGIN RAISE EXCEPTION 'Restore the pre-235 backup with the matching application version; deleted request data cannot be reconstructed.'; END $$;
