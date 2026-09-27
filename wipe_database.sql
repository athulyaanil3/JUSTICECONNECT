-- WARNING: This script will delete ALL data from your database to give you a completely fresh start!

-- 1. Delete all app data
DELETE FROM public.case_updates;
DELETE FROM public.cases;
DELETE FROM public.chat_messages;
DELETE FROM public.consultation_requests;
DELETE FROM public.app_notifications;
DELETE FROM public.lawyer_reviews;

-- 2. Delete all profiles
DELETE FROM public.profiles;

-- 3. Delete all authentication users (This requires admin privileges in Supabase, but works in the SQL editor)
DELETE FROM auth.users;

-- Note: The tables themselves are NOT deleted, only the data inside them. 
-- Your app schema remains intact and ready for new users!
