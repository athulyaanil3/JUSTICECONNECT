-- Allow lawyers and public to read profiles to resolve UUIDs
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Allow public read access to profiles') THEN
        CREATE POLICY "Allow public read access to profiles" ON public.profiles FOR SELECT USING (true);
    END IF;
END $$;
