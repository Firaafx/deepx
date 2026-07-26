-- Ensure storage buckets and policies exist in migration-only deployments.

begin;

insert into storage.buckets (id, name, public)
values ('raymax-assets', 'raymax-assets', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('raymax-avatars', 'raymax-avatars', true)
on conflict (id) do update set public = excluded.public;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_assets_select_public'
  ) THEN
    CREATE POLICY raymax_assets_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'raymax-assets');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_assets_insert_own_folder'
  ) THEN
    CREATE POLICY raymax_assets_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'raymax-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_assets_update_own_folder'
  ) THEN
    CREATE POLICY raymax_assets_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'raymax-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_assets_delete_own_folder'
  ) THEN
    CREATE POLICY raymax_assets_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'raymax-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_avatars_select_public'
  ) THEN
    CREATE POLICY raymax_avatars_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'raymax-avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_avatars_insert_own_folder'
  ) THEN
    CREATE POLICY raymax_avatars_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'raymax-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_avatars_update_own_folder'
  ) THEN
    CREATE POLICY raymax_avatars_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'raymax-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'raymax_avatars_delete_own_folder'
  ) THEN
    CREATE POLICY raymax_avatars_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'raymax-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END $$;

commit;
