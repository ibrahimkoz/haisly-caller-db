-- Dropped modules and configuration data cannot be reconstructed from current campaign settings.
DO $$ BEGIN RAISE EXCEPTION 'Restore the pre-234 database backup together with the matching application version.'; END $$;
