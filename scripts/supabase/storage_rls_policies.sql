-- ==============================================================================
-- MACHALERT — SUPABASE STORAGE ROW-LEVEL SECURITY (RLS) POLICIES
-- Project: MachAlert-Storage (klerkuqcpizqfkaksbrl)
-- Bucket: fault-images (PRIVATE)
-- ==============================================================================

-- 1. Ensure bucket 'fault-images' exists and is private
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fault-images',
  'fault-images',
  false,
  5242880, -- 5 MB in bytes (5 * 1024 * 1024)
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- 2. Drop any legacy/duplicate policies on storage.objects for this bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload fault photos in own folder" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to read fault photos according to MachAlert role" ON storage.objects;
DROP POLICY IF EXISTS "Deny all client updates" ON storage.objects;
DROP POLICY IF EXISTS "Deny all client deletes" ON storage.objects;

-- ------------------------------------------------------------------------------
-- 3. INSERT POLICY
-- - Only authenticated Firebase users (role == 'authenticated')
-- - Upload path must begin with authenticated Firebase UID: (storage.foldername(name))[1] = auth.jwt()->>'sub'
-- - Validates bucket ID is 'fault-images'
-- - Validates permitted image types
-- - Enforces maximum image size of 5 MB (5,242,880 bytes)
-- ------------------------------------------------------------------------------
CREATE POLICY "Allow authenticated users to upload fault photos in own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'fault-images'
  AND (auth.jwt()->>'role') = 'authenticated'
  AND (storage.foldername(name))[1] = (auth.jwt()->>'sub')
  AND (
    (metadata->>'mimetype') IN ('image/jpeg', 'image/png', 'image/webp', 'image/jpg')
    OR (metadata->>'mimetype') LIKE 'image/%'
  )
  AND (
    (metadata->>'size')::numeric <= 5242880
  )
);

-- ------------------------------------------------------------------------------
-- 4. SELECT POLICY
-- - Reporter can read their own photos: (storage.foldername(name))[1] = auth.jwt()->>'sub'
-- - Technician can read plant-wide fault photos: auth.jwt()->>'machalert_role' = 'technician'
-- - Manager can read plant-wide fault photos: auth.jwt()->>'machalert_role' = 'manager'
-- - Foreign operators cannot read another user's photos
-- - Unauthenticated requests are denied
-- ------------------------------------------------------------------------------
CREATE POLICY "Allow users to read fault photos according to MachAlert role"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'fault-images'
  AND (auth.jwt()->>'role') = 'authenticated'
  AND (
    -- Reporter owns the photo attachment
    (storage.foldername(name))[1] = (auth.jwt()->>'sub')
    -- OR Technician role reading plant-wide faults
    OR (auth.jwt()->>'machalert_role') = 'technician'
    -- OR Manager role reading plant-wide faults
    OR (auth.jwt()->>'machalert_role') = 'manager'
  )
);

-- ------------------------------------------------------------------------------
-- 5. UPDATE / DELETE POLICIES
-- - Client-side updates and deletes are strictly prohibited
-- - Preserves incident-history integrity and non-repudiation
-- - No policies are granted for UPDATE or DELETE, which Postgres RLS denies by default
-- ------------------------------------------------------------------------------
