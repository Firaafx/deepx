DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum
    WHERE enumtypid = 'public.render_mode'::regtype
      AND enumlabel = '360'
  ) THEN
    ALTER TYPE public.render_mode ADD VALUE '360';
  END IF;
END $$;
