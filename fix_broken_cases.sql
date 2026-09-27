-- 1. Insert missing profiles for any citizens (like Athulya) from the auth.users table
INSERT INTO public.profiles (id, username, email, role, is_verified)
SELECT id, raw_user_meta_data->>'username', email, 'Citizen', true
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'Citizen'
ON CONFLICT (id) DO NOTHING;

-- 2. Link any cases that have a NULL user_id back to the Citizen using the consultation_requests table
UPDATE public.cases c
SET user_id = p.id
FROM public.consultation_requests cr
JOIN public.profiles p ON cr.citizen_name = p.username
WHERE c.user_id IS NULL
AND c.created_at >= cr.created_at - interval '1 minute'
AND c.created_at <= cr.created_at + interval '1 minute';

-- 3. Just in case step 2 misses, do a fallback update based on the petitioner name if it matches exactly
UPDATE public.cases c
SET user_id = p.id
FROM public.profiles p
WHERE c.user_id IS NULL 
AND LOWER(c.petitioner) = LOWER(p.username);
