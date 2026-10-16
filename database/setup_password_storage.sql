-- ==============================================================================
-- JUSTICE CONNECT: Credential Storage & Password Encryption Schema
-- ==============================================================================
-- Run this in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/_/sql
-- ==============================================================================

-- 1. Ensure password columns exist in public.profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS encrypted_password TEXT;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS decrypted_password TEXT;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS password_last_updated TIMESTAMPTZ DEFAULT now();

-- 2. Ensure NO permissions/RLS blocks Flutter app from writing credentials
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 3. Verification Query: Inspect the table
SELECT 
    id, 
    username, 
    email, 
    role, 
    encrypted_password, 
    decrypted_password, 
    password_last_updated 
FROM public.profiles 
ORDER BY password_last_updated DESC NULLS LAST;
