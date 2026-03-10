-- Ensure storage buckets and policies exist in migration-only deployments.

begin;

insert into storage.buckets (id, name, public)
values ('deepx-assets', 'deepx-assets', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('deepx-avatars', 'deepx-avatars', true)
on conflict (id) do update set public = excluded.public;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_select_public'
  ) THEN
    CREATE POLICY deepx_assets_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'deepx-assets');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_insert_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_update_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_delete_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_select_public'
  ) THEN
    CREATE POLICY deepx_avatars_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'deepx-avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_insert_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_update_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_delete_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END $$;

commit;
