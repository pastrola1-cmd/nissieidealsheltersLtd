-- Property images on Supabase Storage (CORS *) instead of website hotlinks.
-- Website host sent no Access-Control-Allow-Origin, breaking CanvasKit loads.
-- Applied live 2026-09-28: bucket created, 22 files migrated, URLs swapped.

INSERT INTO storage.buckets (id, name, public)
VALUES ('property-images', 'property-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "property_images_public_read" ON storage.objects;
CREATE POLICY "property_images_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'property-images');

DROP POLICY IF EXISTS "property_images_auth_write" ON storage.objects;
CREATE POLICY "property_images_auth_write" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'property-images');

DROP POLICY IF EXISTS "property_images_anon_migrate" ON storage.objects;
