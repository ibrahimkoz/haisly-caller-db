DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.contact_import_previews) THEN
  RAISE EXCEPTION 'Refusing to discard stored import previews; reconcile retained files and data first';
 END IF;
END $$;
DROP TABLE public.contact_import_preview_rows;
DROP TABLE public.contact_import_previews;
