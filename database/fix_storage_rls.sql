-- ============================================================
-- FIX STORAGE RLS POLICIES FOR 'documents' & 'avatars' BUCKETS
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ybgtoaewzrjdlogxjoam/sql
-- ============================================================

-- 1. Ensure 'documents' bucket exists and is PUBLIC
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documents', 'documents', true, 52428800, null)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Ensure 'avatars' bucket exists and is PUBLIC
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 10485760, null)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Drop any conflicting or restrictive policies on storage.objects
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Documents are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload a document." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update a document." ON storage.objects;
DROP POLICY IF EXISTS "Allow public view documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow all uploads to documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow all updates to documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from documents" ON storage.objects;

DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload an avatar." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update an avatar." ON storage.objects;
DROP POLICY IF EXISTS "Allow public view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow all uploads to avatars" ON storage.objects;

-- 4. Create permissive policies for 'documents' bucket
-- Allows users (including newly registered clerks & lawyers) to upload verification documents
CREATE POLICY "Allow public view documents"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'documents');

CREATE POLICY "Allow all uploads to documents"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'documents');

CREATE POLICY "Allow all updates to documents"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'documents')
WITH CHECK (bucket_id = 'documents');

CREATE POLICY "Allow all deletes from documents"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'documents');

-- 5. Create permissive policies for 'avatars' bucket
CREATE POLICY "Allow public view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

CREATE POLICY "Allow all uploads to avatars"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Allow all updates to avatars"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'avatars')
WITH CHECK (bucket_id = 'avatars');
