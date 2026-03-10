-- Allow Post Studio draft state to be stored in mode_states.mode.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum
    WHERE enumtypid = 'public.render_mode'::regtype
      AND enumlabel = 'post_studio_draft'
  ) THEN
    ALTER TYPE public.render_mode ADD VALUE 'post_studio_draft';
  END IF;
END $$;
